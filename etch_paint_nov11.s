# Etch-Paint, Nov 11 goals (these two goals only)
#   Goal 1 / Core 1: implement and test input polling: the mouse (x, y, left button)
#                    and one keyboard control (C)
#   Goal 2 / Core 2: implement coordinate mapping and draw marks at the centre and
#                    edges of the framebuffer
#
# What it does
#   1. init_display reads W and H, clears the screen, draws the self-test marks through
#      paint_at (so every mark goes through map_coordinates) and presents once:
#        red    = centre            green = the four corners
#        blue   = the four edge midpoints
#        yellow = a mark REQUESTED at x = W+100 (off screen); it must land on the right edge
#   2. poll_loop polls the inputs on every pass and shows what it detected on the LEDs:
#        LED0 lights while the left mouse button is held
#        LED1 toggles on every press of C (either case)
#      After poll_input returns, a0 = mouse x, a1 = mouse y, a2 = buttons, a3 = key,
#      so you can also watch the mouse position in the register view.
# The mouse does NOT draw yet: polling and drawing are not connected in this version.
# Click the screen once for keyboard focus.
#
# Register plan
#   s1 = framebuffer width W, s2 = height H (read once in init_display, never changed)
#   s3 = LED state (bit1 toggles when the key is detected)
#   s4..s7 = test_marks locals (saved/restored on the stack)
#   a0..a3 = arguments / return values, t0..t6 = scratch
#   Leaf routines use no stack; paint_at, init_display and test_marks save ra.

.equ FB,           0x20000000   # 1 byte per pixel = palette index
.equ VGACTL,       0x21001000   # +0 width (read), +4 height (read)
.equ PRESENT,      0x21001008   # write anything: show the frame
.equ CLEAR,        0x2100100c   # write color index: fill whole screen
.equ DEV,          0x40000000
.equ LED,          0x00         # out: low 8 bits drive 8 LEDs
.equ KEYHIT,       0x2c         # in : next buffered key (ASCII), 0 if none
.equ MOUSE_X,      0x30         # in : mouse x in framebuffer pixels
.equ MOUSE_Y,      0x34         # in : mouse y in framebuffer pixels
.equ MOUSE_BTN,    0x38         # in : bit0 = left button
.equ BTN_LEFT,     1
.equ KEY_CTRL,     99           # chosen keyboard control: 'c'
.equ BRUSH_R,      1            # brush is (2R+1) x (2R+1) pixels
.equ COLOR_CENTER, 2            # red
.equ COLOR_CORNER, 3            # green
.equ COLOR_EDGE,   4            # blue
.equ COLOR_CLAMP,  5            # yellow

.text
main:
    call init_display
    li   s3, 0                # LED state

poll_loop:
    call poll_input           # a0=x a1=y a2=buttons a3=key
    ori  t0, a3, 0x20         # fold 'C' into 'c'
    li   t1, KEY_CTRL
    bne  t0, t1, pl_leds
    xori s3, s3, 2            # key detected: toggle LED1
pl_leds:
    andi t0, a2, BTN_LEFT     # 1 while the left button is held
    andi t1, s3, 2
    or   t1, t1, t0           # LED0 = button, LED1 = key toggle
    li   t2, DEV
    sw   t1, LED(t2)
    j    poll_loop

# poll_input: returns a0=mouse x, a1=mouse y, a2=button bits, a3=key (0 if none)
poll_input:
    li   t0, DEV
    lw   a0, MOUSE_X(t0)
    lw   a1, MOUSE_Y(t0)
    lw   a2, MOUSE_BTN(t0)
    lw   a3, KEYHIT(t0)       # consumes one buffered key
    ret

# map_coordinates: clamp a0=x to [0,W-1] and a1=y to [0,H-1]
map_coordinates:
    bgez a0, mc_xhi
    li   a0, 0
mc_xhi:
    addi t0, s1, -1
    ble  a0, t0, mc_y
    mv   a0, t0
mc_y:
    bgez a1, mc_yhi
    li   a1, 0
mc_yhi:
    addi t0, s2, -1
    ble  a1, t0, mc_done
    mv   a1, t0
mc_done:
    ret

# draw_brush: a0=cx, a1=cy, a2=color. Paints a (2R+1)^2 square, clipped to the screen.
# Pixel address = FB + py*W + px
draw_brush:
    li   t0, -BRUSH_R         # dy
db_row:
    li   t4, BRUSH_R
    bgt  t0, t4, db_done
    add  t2, a1, t0           # py = cy + dy
    bltz t2, db_next_row      # above the screen
    bge  t2, s2, db_next_row  # below the screen
    li   t1, -BRUSH_R         # dx
db_col:
    li   t4, BRUSH_R
    bgt  t1, t4, db_next_row
    add  t3, a0, t1           # px = cx + dx
    bltz t3, db_next_col      # left of the screen
    bge  t3, s1, db_next_col  # right of the screen
    mul  t4, t2, s1           # py * W
    add  t4, t4, t3           # + px
    li   t5, FB
    add  t4, t4, t5
    sb   a2, 0(t4)            # light the pixel
db_next_col:
    addi t1, t1, 1
    j    db_col
db_next_row:
    addi t0, t0, 1
    j    db_row
db_done:
    ret

# paint_at: a0=x, a1=y, a2=color. map_coordinates then draw_brush (non-leaf, saves ra)
paint_at:
    addi sp, sp, -16
    sw   ra, 12(sp)
    call map_coordinates
    call draw_brush
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# present_frame: the screen only updates when PRESENT is written
present_frame:
    li   t0, PRESENT
    sw   t0, 0(t0)
    ret

# init_display: read W,H, clear the screen, draw the self-test marks, present
init_display:
    addi sp, sp, -16
    sw   ra, 12(sp)
    li   t0, VGACTL
    lw   s1, 0(t0)            # W
    lw   s2, 4(t0)            # H
    li   t0, CLEAR
    sw   zero, 0(t0)          # whole screen to color 0 (black)
    call test_marks
    call present_frame
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# test_marks: marks at the centre, corners and edge midpoints, plus one off-screen request
test_marks:
    addi sp, sp, -32
    sw   ra, 28(sp)
    sw   s4, 24(sp)
    sw   s5, 20(sp)
    sw   s6, 16(sp)
    sw   s7, 12(sp)
    addi s4, s1, -1           # xmax = W-1
    addi s5, s2, -1           # ymax = H-1
    srli s6, s1, 1            # xmid = W/2
    srli s7, s2, 1            # ymid = H/2

    mv   a0, s6               # centre (red)
    mv   a1, s7
    li   a2, COLOR_CENTER
    call paint_at

    li   a0, 0                # top-left corner (green)
    li   a1, 0
    li   a2, COLOR_CORNER
    call paint_at
    mv   a0, s4               # top-right
    li   a1, 0
    li   a2, COLOR_CORNER
    call paint_at
    li   a0, 0                # bottom-left
    mv   a1, s5
    li   a2, COLOR_CORNER
    call paint_at
    mv   a0, s4               # bottom-right
    mv   a1, s5
    li   a2, COLOR_CORNER
    call paint_at

    mv   a0, s6               # top edge middle (blue)
    li   a1, 0
    li   a2, COLOR_EDGE
    call paint_at
    mv   a0, s6               # bottom edge middle
    mv   a1, s5
    li   a2, COLOR_EDGE
    call paint_at
    li   a0, 0                # left edge middle
    mv   a1, s7
    li   a2, COLOR_EDGE
    call paint_at
    mv   a0, s4               # right edge middle
    mv   a1, s7
    li   a2, COLOR_EDGE
    call paint_at

    addi a0, s1, 100          # clamp test: x = W+100 is off screen (yellow)
    srli a1, s2, 2            # y = H/4
    li   a2, COLOR_CLAMP
    call paint_at             # must appear on the right edge at y = H/4

    lw   ra, 28(sp)
    lw   s4, 24(sp)
    lw   s5, 20(sp)
    lw   s6, 16(sp)
    lw   s7, 12(sp)
    addi sp, sp, 32
    ret
