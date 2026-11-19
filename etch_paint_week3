# =====================================================================
# Etch-Paint (final) - a paint program for the MustyV Playground
# =====================================================================
#
# HOW TO USE IT
#   Click the screen once so it has keyboard focus.
#   Hold the LEFT mouse button on the screen to draw. Marks stay on screen.
#   Keys choose the pen color, in rainbow order:
#     1 red   2 orange   3 yellow   4 green   5 blue   6 purple   7 pink   8 grey   9 white
#     0 = eraser (black)
#   C clears the canvas.
#
# GOALS THIS PROGRAM COVERS
#   Core 1  poll the mouse (x, y, left button) and the keyboard on every pass
#   Core 2  map the input to valid framebuffer coordinates and draw a mark there
#   Core 3  one continuous loop (poll -> map -> draw -> present) that keeps old marks
#   Add-on  keyboard color selection (0-9) and clear canvas (C)
#
# LEDS (a quick way to see what the program detected)
#   LED3..LED0 = current pen color number (1-9, 0 = eraser)     LED7 = left button is held
#
# HOW THE PROGRAM IS ORGANISED (read top to bottom)
#   main / main_loop  - the endless loop that does everything, once per "pass"
#   poll_input        - reads the mouse and keyboard registers
#   map_coordinates   - forces a position so the whole brush mark stays on screen
#   draw_brush        - draws one square mark
#   draw_line         - draws marks along a path so fast mouse moves leave no gaps
#   clear_framebuffer - fills the screen with the background color
#   present_frame     - makes the monitor show what we drew
#   init_palette      - loads the rainbow colors into palette entries 1-9
#   init_display      - one-time setup at startup
#
# REGISTER PLAN (these registers keep their meaning for the whole program)
#   s1 = framebuffer width W        s2 = framebuffer height H   (read once, never changed)
#   s3 = current pen color (palette index 0..9)
#   s4, s5 = x, y of the previous mark position (only valid while s6 = 1)
#   s6 = 1 if the left button was down on the previous pass, 0 if it was up
#   a0..a4 = arguments and return values, t0..t6 = scratch (temporary) registers
#   Leaf routines (they call nobody) use no stack; init_display and draw_line
#   call other routines, so they save ra on the stack first.

# ---------------------------------------------------------------------
# Constants (.equ gives a name to a number; it uses no memory)
# ---------------------------------------------------------------------
.equ FB,           0x20000000   # framebuffer: 1 byte per pixel = palette index
.equ PALETTE,      0x21000000   # palette: 256 words, each 0x00RRGGBB (entry n is at PALETTE + 4*n)
.equ VGACTL,       0x21001000   # +0 = width (read), +4 = height (read)
.equ PRESENT,      0x21001008   # write anything: show the frame on the monitor
.equ CLEAR,        0x2100100c   # write a color index: fill the whole screen
.equ DEV,          0x40000000   # base address of the input/output devices
.equ LED,          0x00         # DEV+0x00 (out): low 8 bits drive the 8 LEDs
.equ KEYHIT,       0x2c         # DEV+0x2c (in): next buffered key (ASCII), 0 if none
.equ MOUSE_X,      0x30         # DEV+0x30 (in): mouse x in framebuffer pixels
.equ MOUSE_Y,      0x34         # DEV+0x34 (in): mouse y in framebuffer pixels
.equ MOUSE_BTN,    0x38         # DEV+0x38 (in): bit0 = left button
.equ BTN_LEFT,     1            # mask for the left-button bit
.equ KEY_CLEAR,    99           # ASCII 'c' : clears the canvas
.equ KEY_0,        48           # ASCII '0' : keys '0'..'9' choose the pen color
.equ MAX_COLOR,    9            # we use palette entries 0..9 (0 = black, 1..9 = rainbow)
.equ NUM_COLORS,   9            # how many colors are in palette_table
.equ MARK_SIZE,    1            # the brush is MARK_SIZE x MARK_SIZE pixels. 1 = a single-pixel
                                #   pen (most precise). An odd size (1, 3, 5) is exactly centred
                                #   on the cursor; try 2 or 3 for a thicker line.
.equ COLOR_BG,     0            # palette 0 = black (the background)
.equ COLOR_PEN,    9            # palette 9 = white (the starting pen color)

# ---------------------------------------------------------------------
# Data: the text printed once to the console at startup
# ---------------------------------------------------------------------
.data
# The pen colors, in the order of the number keys 1..9 (each word is 0x00RRGGBB).
# init_palette copies these into palette entries 1..9.
palette_table:
    .word 0xFF0000            # 1 red
    .word 0xFF8000            # 2 orange
    .word 0xFFFF00            # 3 yellow
    .word 0x00C800            # 4 green
    .word 0x2060FF            # 5 blue
    .word 0x8A2BE2            # 6 purple
    .word 0xFF69B4            # 7 pink
    .word 0x808080            # 8 grey
    .word 0xFFFFFF            # 9 white
msg: .string "Etch-Paint: hold the left mouse button to draw. Keys: 1 red, 2 orange, 3 yellow, 4 green, 5 blue, 6 purple, 7 pink, 8 grey, 9 white, 0 eraser, C clears the canvas\n"

.text
# ---------------------------------------------------------------------
# main: one-time setup, then fall into the endless loop
# ---------------------------------------------------------------------
main:
    call init_display         # read screen size, clear the screen, print the controls
    li   s3, COLOR_PEN        # start with the white pen
    li   s6, 0                # the left button was up on the "previous" pass

# ---------------------------------------------------------------------
# main_loop: one pass = read inputs, react to them, show the result.
# It repeats forever, so the program keeps responding to new input.
# Marks are never erased by the loop itself: we only WRITE pixels, so
# everything drawn earlier stays in the framebuffer (that is Core 3).
# ---------------------------------------------------------------------
main_loop:
    call poll_input           # a0=mouse x, a1=mouse y, a2=buttons, a3=key (0 if none)

    # ---- keyboard: C clears the canvas, 0-9 choose the pen color ----
    ori  t0, a3, 0x20         # setting bit 5 turns an upper-case letter into lower case
    li   t1, KEY_CLEAR        # t1 = 'c'
    bne  t0, t1, ml_color     # not C/c -> go check whether it is a digit key
    call clear_framebuffer    # C pressed: wipe the screen (leaf routine, leaves a0..a3 alone)
    j    ml_mouse             # then carry on with the mouse handling
ml_color:
    addi t0, a3, -KEY_0       # t0 = key - '0'  (negative if there was no key or it is not a digit)
    bltz t0, ml_mouse         # below '0' (or no key at all): not a color key
    li   t1, MAX_COLOR        # t1 = 9
    bgt  t0, t1, ml_mouse     # above '9': not a color key
    mv   s3, t0               # a digit was pressed: it becomes the pen color (0 = black = eraser)

    # ---- mouse: the left button draws ----
ml_mouse:
    andi t0, a2, BTN_LEFT     # keep only the left-button bit (1 = held, 0 = up)
    beqz t0, ml_up            # button up: nothing to draw this pass
    li   t0, MARK_SIZE
    srli t0, t0, 1            # t0 = half a mark, rounded down (1 -> 0, 3 -> 1). With size 1 this
                              #   is 0, so the mark is exactly the pixel under the cursor
    sub  a0, a0, t0           # shift left/up by half a mark so the mark is
    sub  a1, a1, t0           #   centred on the cursor (a0,a1 were the cursor position)
    call map_coordinates      # a0,a1 = valid top-left corner (mark stays fully on screen)
    mv   a3, a0               # a3,a4 = END of this segment = current position
    mv   a4, a1
    beqz s6, ml_draw          # button was UP last pass: this is the first point of a
                              #   stroke, so start = end (a0,a1 already hold it)
    mv   a0, s4               # button was already down: start from the previous position
    mv   a1, s5               #   so the stroke is connected with no gaps
ml_draw:
    mv   a2, s3               # color for draw_line = the current pen color
    call draw_line            # draws start -> end (just one mark if they are equal)
    mv   s4, a3               # remember this position; draw_line leaves a3,a4 unchanged
    mv   s5, a4
    li   s6, 1                # button is down this pass
    j    ml_show
ml_up:
    li   s6, 0                # button up: the next press starts a NEW stroke

    # ---- show the result ----
ml_show:
    slli t0, s6, 7            # s6 (0/1) shifted to bit 7: LED7 = button held
    or   t0, t0, s3           # low bits = pen color number: LED3..LED0
    li   t1, DEV
    sw   t0, LED(t1)          # write the LED pattern
    call present_frame        # the monitor only updates when PRESENT is written
    j    main_loop            # start the next pass

# ---------------------------------------------------------------------
# poll_input: read the mouse and keyboard registers (Core 1).
#   returns a0 = mouse x, a1 = mouse y, a2 = button bits, a3 = key (0 if none)
# Leaf routine: no stack needed.
# ---------------------------------------------------------------------
poll_input:
    li   t0, DEV              # t0 = base address of the devices
    lw   a0, MOUSE_X(t0)      # mouse x, already in framebuffer pixels
    lw   a1, MOUSE_Y(t0)      # mouse y, already in framebuffer pixels
    lw   a2, MOUSE_BTN(t0)    # bit0 = left button
    lw   a3, KEYHIT(t0)       # next key press; reading it REMOVES it from the buffer
    ret

# ---------------------------------------------------------------------
# map_coordinates: keep a whole mark on the screen (Core 2).
#   in/out: a0 = x clamped to [0, W-MARK_SIZE]
#           a1 = y clamped to [0, H-MARK_SIZE]
# The position is the mark's TOP-LEFT corner, so the largest legal value
# is W-MARK_SIZE; any further right and the mark would run off the right
# edge (and wrap onto the next row).  Leaf routine.
# ---------------------------------------------------------------------
map_coordinates:
    bgez a0, mc_xhi           # x >= 0 ?  then the left side is fine
    li   a0, 0                # x was negative: use the left edge
mc_xhi:
    addi t0, s1, -MARK_SIZE   # t0 = xmax = W - MARK_SIZE
    ble  a0, t0, mc_y         # x <= xmax ?  then the right side is fine
    mv   a0, t0               # x was too big: use the right-most legal position
mc_y:
    bgez a1, mc_yhi           # same idea for y: y >= 0 ?
    li   a1, 0                # y was negative: use the top edge
mc_yhi:
    addi t0, s2, -MARK_SIZE   # t0 = ymax = H - MARK_SIZE
    ble  a1, t0, mc_done      # y <= ymax ?  then the bottom is fine
    mv   a1, t0               # y was too big: use the bottom-most legal position
mc_done:
    ret

# ---------------------------------------------------------------------
# draw_brush: draw one MARK_SIZE x MARK_SIZE square.
#   a0 = x, a1 = y (top-left corner), a2 = color (palette index)
# Pixel address = FB + y*W + x   (rows are W bytes long, 1 byte per pixel).
# Uses only t1..t5 and never changes a0..a4, so callers keep their values.
# Leaf routine.
# ---------------------------------------------------------------------
draw_brush:
    li   t1, 0                # t1 = row number inside the mark (0 .. MARK_SIZE-1)
mark_row:
    li   t2, MARK_SIZE        # t2 = number of rows / columns in the mark
    bge  t1, t2, mark_done    # all rows drawn: finished
    li   t3, 0                # t3 = column number inside the mark (0 .. MARK_SIZE-1)
mark_col:
    bge  t3, t2, next_row     # all columns of this row drawn: go to the next row
    add  t4, a1, t1           # t4 = y of this pixel = top y + row
    mul  t4, t4, s1           # t4 = y * W   (start of that row, in bytes)
    add  t4, t4, a0           # t4 = y * W + top x
    add  t4, t4, t3           # t4 = y * W + x   (x = top x + column)
    li   t5, FB               # t5 = framebuffer base address
    add  t4, t4, t5           # t4 = FB + y*W + x = the pixel's address
    sb   a2, 0(t4)            # store the color byte: the pixel lights up
    addi t3, t3, 1            # next column
    j    mark_col
next_row:
    addi t1, t1, 1            # next row
    j    mark_row
mark_done:
    ret

# ---------------------------------------------------------------------
# draw_line: draw marks along a path from a start point to an end point.
#   a0,a1 = start, a3,a4 = end (both already valid), a2 = color
# The mouse is only sampled between passes, so a fast move jumps several
# pixels; stamping a mark at every step of the path fills that gap.
# It stamps a mark at the start, then steps ONE pixel at a time toward the
# end (diagonal first, then straight) until the end point is reached.
# On return a0,a1 = the end point; a2, a3, a4 are unchanged.
# This routine CALLS draw_brush, which overwrites ra, so it saves ra on the stack.
# ---------------------------------------------------------------------
draw_line:
    addi sp, sp, -16          # make room on the stack (16 bytes keeps sp aligned)
    sw   ra, 12(sp)           # save our return address
dl_loop:
    call draw_brush           # stamp a mark at the current point (a0, a1)
    bne  a0, a3, dl_step      # x not at the end yet: keep moving
    beq  a1, a4, dl_done      # x at the end AND y at the end: finished
dl_step:
    beq  a0, a3, dl_y         # x already equals the end x: leave x alone
    blt  a0, a3, dl_xup       # x is left of the end: move right
    addi a0, a0, -1           # x is right of the end: move left one pixel
    j    dl_y
dl_xup:
    addi a0, a0, 1            # move right one pixel
dl_y:
    beq  a1, a4, dl_loop      # y already equals the end y: leave y alone
    blt  a1, a4, dl_yup       # y is above the end: move down
    addi a1, a1, -1           # y is below the end: move up one pixel
    j    dl_loop
dl_yup:
    addi a1, a1, 1            # move down one pixel
    j    dl_loop              # stamp the next mark
dl_done:
    lw   ra, 12(sp)           # restore our return address
    addi sp, sp, 16           # give the stack space back
    ret

# ---------------------------------------------------------------------
# clear_framebuffer: fill the whole screen with the background color.
# One store to the CLEAR register does it all. Uses only t0 and t1.
# ---------------------------------------------------------------------
clear_framebuffer:
    li   t0, CLEAR            # t0 = address of the clear register
    li   t1, COLOR_BG         # t1 = background color (black)
    sw   t1, 0(t0)            # writing a color index fills the screen with it
    ret

# ---------------------------------------------------------------------
# present_frame: tell the simulator to show what is in the framebuffer.
# Drawing alone does not change the monitor; it only updates when
# PRESENT is written (any value works).
# ---------------------------------------------------------------------
present_frame:
    li   t0, PRESENT          # t0 = address of the present register
    sw   t0, 0(t0)            # write anything to it
    ret

# ---------------------------------------------------------------------
# init_palette: load the rainbow colors into palette entries 1..9.
# The framebuffer stores palette INDEXES, so changing what an index means
# recolors that pen. Entry 0 is left alone (black, used for the background
# and as the eraser). It copies NUM_COLORS words from palette_table to
# PALETTE + 4. Leaf routine: uses only t0..t4.
# ---------------------------------------------------------------------
init_palette:
    la   t0, palette_table    # t0 = address of the next color in our table
    li   t1, PALETTE
    addi t1, t1, 4            # t1 = address of palette entry 1 (entry 0 stays black)
    li   t2, 0                # t2 = how many colors copied so far
ip_loop:
    li   t3, NUM_COLORS
    bge  t2, t3, ip_done      # copied all of them: finished
    lw   t4, 0(t0)            # t4 = the color 0x00RRGGBB from the table
    sw   t4, 0(t1)            # store it into the palette entry
    addi t0, t0, 4            # next table word
    addi t1, t1, 4            # next palette entry
    addi t2, t2, 1            # one more color copied
    j    ip_loop
ip_done:
    ret

# ---------------------------------------------------------------------
# init_display: one-time setup.
# Reads the screen size, loads the colors, clears the screen, shows it, prints the controls.
# It calls other routines, so it saves ra on the stack.
# ---------------------------------------------------------------------
init_display:
    addi sp, sp, -16          # make room on the stack
    sw   ra, 12(sp)           # save our return address
    li   t0, VGACTL           # t0 = address of the display control block
    lw   s1, 0(t0)            # s1 = framebuffer width W  (used by every address calculation)
    lw   s2, 4(t0)            # s2 = framebuffer height H (used for the bottom edge)
    call init_palette         # load the rainbow colors (before the first present)
    call clear_framebuffer    # display init: whole screen to black
    call present_frame        # show the black screen (and the new palette)
    la   a0, msg              # a0 = address of the text to print
    li   a7, 4                # ecall 4 = print string
    ecall                     # print the controls to the console
    lw   ra, 12(sp)           # restore our return address
    addi sp, sp, 16           # give the stack space back
    ret
