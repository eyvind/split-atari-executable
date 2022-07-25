ICCOM      = $0342
ICBAL      = $0344
ICBAH      = $0345
ICBLL      = $0348
ICBLH      = $0349
ICAX1      = $034A
ICAX2      = $034B

RUNAD      = $02E0
INITAD     = $02E2
CIOV       = $E456

OPEN       = $03
GETCHR     = $07
PUTREC     = $09
CLOSE      = $0C

EOFERR     = $88

start_addr = $80
end_addr   = $82
length     = $84

	org $9800

start
	mwa #return RUNAD
read_files
	jsr read_file
	bmi print_error
	inc index
	lda index
	cmp #$30+num_files
	bcc read_files
	jmp (RUNAD)

print_error
	ldx #$00
	mwa #errmess ICBAL,x
	mwa #messend-errmess ICBLL,x
	lda #PUTREC
	sta ICCOM,x
	jmp CIOV

open_file
	ldx #$10
	lda #CLOSE
	sta ICCOM,x
	jsr CIOV
	mwa #fname ICBAL,x
	lda #OPEN
	sta ICCOM,x
	lda #$64
	sta ICAX1,x
	lda #$02
	sta ICAX2,x
	jmp CIOV

read_file
	jsr open_file
	bmi read_error
read_loop
	mwa #return INITAD
	jsr read_segment
	bmi read_error
	lda #>(read_loop-1)
	pha
	lda #<(read_loop-1)
	pha
	jmp (INITAD)
read_error
	php
	tya
	pha
	lda #CLOSE
	sta ICCOM,x
	jsr CIOV
	pla
	tay
	cpy #EOFERR
	bne return_error
	plp
	ldy #$01
	rts
return_error
	plp
return	rts

read_segment
	jsr read_address
	bmi return
	lda buffer
	and buffer+1
	cmp #$FF
	bne address_ok
	jsr read_address
	bmi return
address_ok
	mwa buffer start_addr
	jsr read_address
	bmi return
	mwa buffer end_addr
	sec
	lda end_addr
	sbc start_addr
	sta length
	lda end_addr+1
	sbc start_addr+1
	sta length+1
	inc length
	sne:inc length+1
	mwa start_addr ICBAL,x
	mwa length ICBLL,x
	lda #GETCHR
	sta ICCOM,x
	jmp CIOV

read_address
	ldx #$10
	mwa #buffer ICBAL,x
	mwa #$0002 ICBLL,x
	lda #GETCHR
	sta ICCOM,x
	jmp CIOV

num_files = 3
errmess	.byte 'Error loading '
fname	.byte 'D:FNCONF'
index	.byte '0.OVL',$9B
messend	.byte 0
buffer	.ds 2

	run start
