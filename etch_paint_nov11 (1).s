# Etch-Paint, Nov 11 goals (builds on the Week 1 test-mark program)
#   Goal 1 / Core 1: implement and test input polling: the mouse (x, y, left button)
#                    and one keyboard control (C)
#   Goal 2 / Core 2: implement coordinate mapping and draw marks at the centre and
#                    edges of the framebuffer
#
# Same mark as Week 1: MARK_SIZE x MARK_SIZE pixels, (x, y) = its TOP-LEFT corner,
# pixel address = FB + y*W + x.  New this week: map_coordinates keeps the whole mark
# on the screen, and the program keeps running to poll the inputs.
#
# What it does
#   1. init_display reads W and H, clears the screen, draws the self-test marks through
#      paint_at (every mark goes through map_coordinates), presents once and prints a note:
#        red    = centre            green = the four corners
#        blue   = the four edge midpoints
#        yellow = a mark REQUESTED at x = W+100 (off screen); it must land on the right edge
#   2. poll_loop polls the inputs on every pass and shows what it detected on the LEDs:
#        LED0 lights while the left mouse button is held
#        LED1 toggles on every press of C (either case)
#      After poll_input returns, a0 = mouse x, a1 = mouse y, a2 = buttons, a3 = key,
#      so the mouse position can also be watched in the register view.
# The mouse does NOT draw yet: polling and drawing are not connected in this version.
# Click the screen once for keyboard focus.
#
# Register plan
#   s1 = framebuffer width W, s2 = height H (read once in init_display, never changed)
#   s3 = LED state (bit1 toggles when the key is detected)
#   s4..s7 = test_marks locals (saved/restored on the stack)
#   a0..a3 = arguments / return values, t0..t6 = scratch

.equ FB,           0x20000000   # framebuffer: 1 byte per pixel = palette index
.equ VGACTL,       0x21001000   # +0 = width (read), +4 = height (read)
.equ PRESENT,      0x21001008   # write anything: show the frame on the monitor
.equ CLEAR,        0x2100100c   # write a color index: fill the whole screen
.equ DEV,          0x40000000
.equ LED,          0x00         # out: low 8 bits drive 8 LEDs
.equ KEYHIT,       0x2c         # in : next buffered key (ASCII), 0 if none
.equ MOUSE_X,      0x30         # in : mouse x in framebuffer pixels
.equ MOUSE_Y,      0x34         # in : mouse y in framebuffer pixels
.equ MOUSE_BTN,    0x38         # in : bit0 = left button
.equ BTN_LEFT,     1
.equ KEY_CTRL,     99           # chosen keyboard control: 'c'
.equ MARK_SIZE,    8            # 8 x 8 pixels
.equ COLOR_BG,     0            # palette 0 = black
.equ COLOR_MARK,   2            # palette 2 = red (centre mark)
.equ COLOR_CORNER, 3            # palette 3 = green
.equ COLOR_EDGE,   4            # palette 4 = blue
.equ COLOR_CLAMP,  5            # palette 5 = yellow

.data
msg: .string "Test marks drawn: red centre, green corners, blue edge midpoints, yellow clamp test (x=W+100 -> right edge)\n"

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

# map_coordinates: keep a whole mark on the screen
#   a0 = x clamped to [0, W-MARK_SIZE], a1 = y clamped to [0, H-MARK_SIZE]
map_coordinates:
    bgez a0, mc_xhi
    li   a0, 0
mc_xhi:
    addi t0, s1, -MARK_SIZE   # xmax = W - MARK_SIZE
    ble  a0, t0, mc_y
    mv   a0, t0
mc_y:
    bgez a1, mc_yhi
    li   a1, 0
mc_yhi:
    addi t0, s2, -MARK_SIZE   # ymax = H - MARK_SIZE
    ble  a1, t0, mc_done
    mv   a1, t0
mc_done:
    ret

# draw_brush: a0 = x, a1 = y (top-left corner), a2 = color
# draws a MARK_SIZE x MARK_SIZE square; pixel address = FB + y*W + x
draw_brush:
    li   t1, 0                # t1 = row (0 .. MARK_SIZE-1)
mark_row:
    li   t2, MARK_SIZE
    bge  t1, t2, mark_done
    li   t3, 0                # t3 = column (0 .. MARK_SIZE-1)
mark_col:
    bge  t3, t2, next_row
    add  t4, a1, t1           # y = a1 + row
    mul  t4, t4, s1           # y * W
    add  t4, t4, a0           # + x
    add  t4, t4, t3           # + column  (= y*W + x)
    li   t5, FB
    add  t4, t4, t5           # + FB base = pixel address
    sb   a2, 0(t4)            # light the pixel
    addi t3, t3, 1
    j    mark_col
next_row:
    addi t1, t1, 1
    j    mark_row
mark_done:
    ret

# paint_at: a0 = x, a1 = y, a2 = color. map_coordinates then draw_brush (saves ra)
paint_at:
    addi sp, sp, -16
    sw   ra, 12(sp)
    call map_coordinates
    call draw_brush
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# present_frame: the monitor only updates when PRESENT is written
present_frame:
    li   t0, PRESENT
    sw   t0, 0(t0)
    ret

# init_display: read W,H, clear the screen, draw the self-test marks, present, print a note
init_display:
    addi sp, sp, -16
    sw   ra, 12(sp)
    li   t0, VGACTL
    lw   s1, 0(t0)            # s1 = framebuffer width W
    lw   s2, 4(t0)            # s2 = framebuffer height H

    li   t0, CLEAR            # display init: whole screen to black
    li   t1, COLOR_BG
    sw   t1, 0(t0)

    call test_marks
    call present_frame
    la   a0, msg              # print what the test marks should look like
    li   a7, 4
    ecall
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
    addi s4, s1, -MARK_SIZE   # xmax = W - MARK_SIZE
    addi s5, s2, -MARK_SIZE   # ymax = H - MARK_SIZE
    srli s6, s4, 1            # xmid = xmax / 2  (centres the mark)
    srli s7, s5, 1            # ymid = ymax / 2

    mv   a0, s6               # centre (red)
    mv   a1, s7
    li   a2, COLOR_MARK
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
