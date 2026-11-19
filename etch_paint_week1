# Etch-Paint, Week 1 Goal 2: one .s file that assembles, runs, and shows a test mark.
# No input and no drawing logic yet. It only does display initialization plus
# ONE test mark at a known position, so the team can check the output by eye.
#
# Expected result: an 8x8 red square with its top-left pixel at (x=100, y=60),
# so it covers x = 100..107 and y = 60..67, on a black screen.
#
# Pixel address = FB + y*W + x   (W is read from the simulator, so any resolution works)

.equ FB,         0x20000000   # framebuffer: 1 byte per pixel = palette index
.equ VGACTL,     0x21001000   # +0 = width (read), +4 = height (read)
.equ PRESENT,    0x21001008   # write anything: show the frame on the monitor
.equ CLEAR,      0x2100100c   # write a color index: fill the whole screen
.equ MARK_X,     100          # test position (top-left corner of the mark)
.equ MARK_Y,     60
.equ MARK_SIZE,  8            # 8 x 8 pixels
.equ COLOR_BG,   0            # palette 0 = black
.equ COLOR_MARK, 2            # palette 2 = red

.data
msg: .string "Test mark drawn at x=100, y=60, size 8x8 (red)\n"

.text
main:
    li   t0, VGACTL
    lw   s1, 0(t0)            # s1 = framebuffer width W

    li   t0, CLEAR            # display init: whole screen to black
    li   t1, COLOR_BG
    sw   t1, 0(t0)

    li   t1, 0                # t1 = row (0 .. MARK_SIZE-1)
mark_row:
    li   t2, MARK_SIZE
    bge  t1, t2, show
    li   t3, 0                # t3 = column (0 .. MARK_SIZE-1)
mark_col:
    bge  t3, t2, next_row
    li   t4, MARK_Y
    add  t4, t4, t1           # y = MARK_Y + row
    mul  t4, t4, s1           # y * W
    li   t5, MARK_X
    add  t4, t4, t5           # + MARK_X
    add  t4, t4, t3           # + column  (= y*W + x)
    li   t5, FB
    add  t4, t4, t5           # + FB base = pixel address
    li   t6, COLOR_MARK
    sb   t6, 0(t4)            # light the pixel
    addi t3, t3, 1
    j    mark_col
next_row:
    addi t1, t1, 1
    j    mark_row

show:
    li   t0, PRESENT          # the monitor only updates when PRESENT is written
    sw   t0, 0(t0)
    la   a0, msg              # print the expected position to the console
    li   a7, 4
    ecall
    li   a7, 10               # exit
    ecall
