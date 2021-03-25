TITLE  Designing low-level I/O procedures

; Author: Hye Yeon Park
; Last Modified:  3/14/2021
; Description: This program introduce program title, programmer name and give
;	program description. The program implement and test two macros, mGetString 
;	and mDisplayString for string processing. It will get user numbers as strings,
;	convert into number, calculate sum and average, convert them back to strings,
;   	and display them. The conversion between string and number is performed using 
;	string primitive instructions, LODSB and STOSB.

INCLUDE Irvine32.inc

;------------------------------------------------------------------------------
; mGetString (macro)
; Display a prompt and get the user’s input into a given memory location
; Receives: 
;		address of prompt
;		address of the memory location
;		length of the memory location
; Returns: user input string in the memory location
; Postconditions: EAX changed
; Registers changed: EDX, ECX
;------------------------------------------------------------------------------
mGetString	MACRO	promptAddress, userInputAddress, userInputSize
	PUSH	EDX
	PUSH	ECX
	MOV	EDX, promptAddress		; display the prompt
	CALL	WriteString
	MOV	EDX, userInputAddress
	MOV	ECX, userInputSize
	CALL	ReadString
	POP	ECX
	POP	EDX
ENDM

;------------------------------------------------------------------------------
; mDisplayString (macro)
; Print the string stored in a specified memory location
; Receives: address of the string
; Returns: display the string to console
; Registers changed: EDX
;------------------------------------------------------------------------------
mDisplayString MACRO strAddress
	PUSH	EDX
	MOV	EDX, strAddress
	CALL	WriteString
	POP	EDX
ENDM


.data

	intro1		BYTE	"PROGRAMMING ASSIGNMENT 6: Designing low-level I/O procedures", 13, 10, \
						"Written by: Hye Yeon Park", 13, 10, 10, \
						"Please provide 10 signed decimal integers.", 13, 10, \  
						"Each number needs to be small enough to fit inside a 32 bit register.", 13, 10, \
						"After you have finished inputting the raw numbers I will display a list", 13, 10, \
						"of the integers, their sum, and their average value.", 13, 10, 10, 0
	prompt1		BYTE	"Please enter a signed number: ", 0
	prompt2		BYTE	"ERROR: You did not enter a signed number or your number was too big.", 13, 10, \
						"Please try again: ", 0
	userInput	BYTE	21 DUP(?)				; saves user input
	numArray	SDWORD	10 DUP(?)
	convertdNum	SDWORD  ?					; number converted from string
	dispTitle	BYTE	13, 10, "You entered the following numbers:", 0
	sumTitle	BYTE	"The sum of these numbers is: ", 0
	avgTitle	BYTE	"The rounded average is: ", 0
	comma		BYTE	", ", 0
	goodBye		BYTE	13, 10, "Thanks for playing!", 13, 10, 0


.code
main	PROC
; intro
	mDisplayString	OFFSET intro1

; get user string, convert to number and store in array
	MOV	EDI, OFFSET numArray
	MOV	ECX, LENGTHOF numArray

	_fillArray:
	PUSH	OFFSET convertdNum
	PUSH	OFFSET prompt1
	PUSH	OFFSET prompt2
	PUSH	OFFSET userInput
	PUSH	LENGTHOF userInput

	; get user string, convert to numeric value
	CALL	ReadVal

	; store converted numbers in array
	MOV	EDX, convertdNum
	MOV	[EDI], EDX		
	ADD	EDI, 4
	LOOP	_fillArray			; repeat to fill the array

; display the array of numbers
	PUSH	OFFSET numArray
	PUSH	LENGTHOF numArray
	PUSH	OFFSET dispTitle
	PUSH	OFFSET comma
	CALL	DisplayArray

; display sum and average
	PUSH	OFFSET numArray
	PUSH	LENGTHOF numArray
	PUSH	OFFSET sumTitle
	PUSH	OFFSET avgTitle
	CALL	DisplaySumAvg

; farewell
	mDisplayString	OFFSET goodBye

	INVOKE	ExitProcess,0			; Exit to operating system
main	ENDP

;------------------------------------------------------------------------------
; ReadVal (Subprocedure: StrToNum)
; Invokes the mGetString macro to get user input in the form of a string, validate the 
; user’s input, calls subprocedure StrToNum to convert the string into numeric value(SDWORD),  
; and stores in a memory variable. 
; Receives: 
;		[EBP + 24] = address of convertdNum
;		[EBP + 20] = address of prompt1
;		[EBP + 16] = address of prompt2
;		[EBP + 12] = address of userInput
;		[EBP + 8] = LENGTHOF userInput
; Returns: a validated and converted number in convertdNum
; Preconditions: strings in userInput
; Registers changed: EAX, EBX, ESI, ECX, EDX
; local variable:
;		isNegative - holds boolean 0/1 for negative values
;		isOverFlow - holds boolean 0/1 for values don't fit in 32 bit register
;		isSigned - holds boolean 0/1 for signed values(+,-)
;------------------------------------------------------------------------------
ReadVal		PROC
	LOCAL	isNegative:DWORD, isOverFlow:DWORD, isSigned:DWORD
	PUSHAD

	MOV	EAX, [EBP + 20]	; address of prompt1 in EAX
_getInput:
	MOV	ESI, [EBP + 12]	; address of userInput
	MOV	ECX, [EBP + 8]	; set loop counter with LENGTHOF userInput
	MOV	isNegative, 0	; reset local variables
	MOV	isOverFlow, 0
	MOV	isSigned, 0
	mGetString	EAX, ESI, ECX

; check each string byte if valid
	MOV	EBX, 0		; work as a counter	
	CLD
_checkStr:
	; check string for invalid characters
	LODSB
	CMP	AL, 0
	JE	_null
	CMP	AL, 43		; check for '+' sign
	JE	_signed
	CMP	AL, 45		; check for '-' sign
	JE	_signed
	CMP	AL, 48
	JL	_invalid
	CMP	AL, 57
	JG	_invalid
	_goBackToLoop:
	INC	EBX
	LOOP	_checkStr
	JMP	_conversion

; if input is negative number
_signed:
	CMP	EBX, 0
	JNE	_invalid	; if sign found in non-first digit, invalid
	MOV	isSigned, 1	; set isSigned to True
	CMP	AL, 43		; if it was '+' sign, go back to loop
	JE	_goBackToLoop
	MOV	isNegative, 1	; otherwise, set isNegative
	JMP	_goBackToLoop

; if string is invalid
_invalid:
	MOV	EAX, [EBP + 16]	; address of prompt2, setup for reprompt user input
	JMP	_getInput

; check if no entry or end of string
_null:
	CMP	EBX, 0		; if no entry
	JE	_invalid
	CMP	EBX, isSigned	; if EBX=isSigned=1 (only sign byte is entered)
	JE	_invalid

; setup for StrToNum procedure
_conversion:
	MOV	isOverFlow, 0			
	MOV	EBX, [EBP + 24]
	PUSH	EBX		; address of convertdNum on stack
	MOV	EBX, [EBP + 12]
	PUSH	EBX		; address of userInput on stack
	MOV	EBX, [EBP + 8]
	PUSH	EBX		; LENGTHOF userInput on stack
	LEA	EBX, isOverFlow
	PUSH	EBX		; address of isOverFlow on stack
	CALL	StrToNum	; string to number conversion

; check if the number is out of range
	MOV	EBX, isOverFlow
	CMP	EBX, 1		; if isOverFlow is 1
	JE	_invalid	; the number is out of range

; if the input was negative number
	MOV	EDI, [EBP + 24]
	MOV	EDX, [EDI]	; convertdNum in EDX
	CMP	isNegative, 1	; if it's negative
	JNE	_end					
	NEG	EDX		; negate the result	
	
_end:
	MOV	[EDI], EDX	; store the result in convertdNum
	POPAD
	RET	20
ReadVal		ENDP

;------------------------------------------------------------------------------
; StrToNum
; Converts string to numeric value using primitives instructions.
; Receives:
;		[EBP + 20] = address of convertdNum
;		[EBP + 16] = address of userInput
;		[EBP + 12] = LENGTHOF userInput
;		[EBP + 8] = address of isOverFlow, a local variable from ReadVal
; Returns: numeric SDWORD value in convertdNum
; Preconditions: strings in userInput
; Registers changed: EBP, ESI, EDI, EAX, EBX, ECX, EDX
;------------------------------------------------------------------------------
StrToNum	PROC
	PUSH	EBP
	MOV	EBP, ESP
	PUSHAD

	MOV	EDI, [EBP + 20]	; address of convertdNum
	MOV	ESI, [EBP + 16]	; address of userInput
	MOV	ECX, [EBP + 12]	; set loop counter with LENGTHOF userInput

; get each string byte into convertdNum
	CLD
	MOV	EDX, 0
	MOV	[EDI], EDX	; reset convertdNum for setup

_conversion:
	LODSB
	CMP	EAX, 0
	JE	_end
	CMP	EAX, 43		; check for plus sign
	JE	_nextLoop	; move to next byte
	CMP	EAX, 45		; check for negative sign
	JE	_nextLoop			
	SUB	EAX, 48		; convert string to number using ASCII table
	MOV	EBX, EAX
	MOV	EAX, [EDI]	; get the already-converted parts
	MOV	EDX, 10			
	IMUL	EDX		; multiply by 10 to make them into the next higher digits
	JO	_outOfRange	; check overflow flag
	ADD	EAX, EBX	; add newly converted digit 
	JO	_outOfRange	; check overflow flag again
	MOV	[EDI], EAX	
	MOV	EAX, 0		; reset EAX
	_nextLoop:
	LOOP	_conversion

; if overflow flag is set
_outOfRange:
	MOV	EBX, [EBP + 8]	; address of isOverFlow
	MOV	EAX, 1		; set isOverFlow to 1(True)
	MOV	[EBX], EAX

_end:	
	POPAD
	POP		EBP
	RET	16
StrToNum	ENDP

;------------------------------------------------------------------------------
; DisplayArray
; Calls procedure WriteVal to convert integers in numArray to strings and display them.
; Invokes mDisplayString to display the dispTitle and comma inbetween the numbers. 
; Receives: 
;		[EBP + 20] = address of numArray
;		[EBP + 16] = LENGTHOF numArray
;		[EBP + 12] = address of dispTitle
;		[EBP + 8] = address of comma
; Returns: displays string form of numbers in numArray into console
; Registers changed: EBP, ESI, EBX, ECX, EDX
;------------------------------------------------------------------------------
DisplayArray	PROC
	PUSH	EBP
	MOV	EBP, ESP
	PUSHAD

	mDisplayString	[EBP + 12]	; address of dispTitle
	CALL	Crlf
	MOV	ESI, [EBP + 20]	; address of numArray
	MOV	ECX, [EBP + 16]	; set loop counter with LENGTHOF numArray

; convert number to string and display
_displayLoop:
	MOV	EBX, [ESI]
	PUSH	EBX		; numArray on stack
	CALL	WriteVal	; convert number to string and print it		
	ADD	ESI, 4		; point to next place
	CMP	ECX, 1
	JE	_end		; no comma at the end
	MOV	EDX, [EBP + 8]			
	mDisplayString	EDX	; display comma
	LOOP	_displayLoop

_end:
	CALL	Crlf
	POPAD
	POP	EBP
	RET	16
DisplayArray	ENDP

;------------------------------------------------------------------------------
; DisplaySumAvg
; Calculate the sum and the average of the numbers in numArray.
; Calls procedure WriteVal to convert them into strings and display.
; Invokes mDisplayString to display the sumTitle and avgTitle.
; Receives: 
;		[EBP + 20] = address of numArray
;		[EBP + 16] = LENGTHOF numArray
;		[EBP + 12] = address of sumTitle
;		[EBP + 8] = address of avgTitle
; Returns: display the sum and the average of the numbers in numArray as a string form
; Registers changed: EBP, ESI, EAX, EBX, ECX, EDX
;------------------------------------------------------------------------------
DisplaySumAvg	PROC
	PUSH	EBP
	MOV	EBP, ESP
	PUSHAD	

; calculate and display sum
	mDisplayString	[EBP + 12]	; display address of sumTitle
	MOV	ESI, [EBP + 20]		; address of numArray
	MOV	ECX, [EBP + 16]		; LENGTHOF numArray
	MOV	EAX, 0			; reset EAX
_sum:
	ADD	EAX, [ESI]	; add up array elements to EAX
	ADD	ESI, 4
	LOOP	_sum	
	PUSH	EAX		; EAX holds sum
	CALL	WriteVal	; convert to string and display sum
	CALL	Crlf

; calculate and display average
	mDisplayString	[EBP + 8]	; display address of avgTitle
	MOV	EBX, [EBP + 16]		; LENGTHOF numArray
	CDQ			; precondition for IDIV
	IDIV	EBX		; divide the sum by LENGTHOF numArray
	ADD	EDX, EDX	; double the remainder
	CMP	EDX, EBX	; compare with divisor
	JL	_saveAvg
	INC	EAX
_saveAvg:
	PUSH	EAX		; EAX holds average
	CALL	WriteVal	; convert to string and display average
	CALL	Crlf

	POPAD
	POP	EBP
	RET	16
DisplaySumAvg	ENDP

;------------------------------------------------------------------------------
; WriteVal
; Converts a numeric SDWORD value to a string and invokes mDisplayString macro to 
; print the ascii representation of the SDWORD value to the output.
; Receives: 
;		[EBP + 8] = numeric SDWORD value
; Returns: displays string to console
; Preconditions: numeric SDWORD values in numArray, the sum and the average are 
;		calculated and passed by value
; Registers changed: EBP, EDI, EAX, EBX, ECX, EDX
; local variable:
;		outString - holds converted strings for display
;		getStack - loads string byte from stack 
;		isNegative - holds boolean 0/1 for negative values
;------------------------------------------------------------------------------
WriteVal	PROC
	LOCAL	outString[21]:BYTE, getStack:DWORD, isNegative:DWORD
	PUSHAD
	MOV	ECX, 0		; reset counter

; convert number to string
	MOV	EBX, 10
	MOV	EAX, [EBP + 8]	; numeric SDWORD value in EAX
	CMP	EAX, 0		; if the number is negative
	JGE	_getDigits
	MOV	isNegative, 1	; set isNegative to 1(True)
	NEG	EAX						
	
; divide integer by 10 and save the remainder to get each digit
_getDigits:
	CDQ
	IDIV	EBX		; divide by 10
	PUSH	EDX		; push the remainder to the stack(order reversed)
	INC	ECX		; increase counter to get the number of digits
	CMP	EAX, 0
	JNE	_getDigits				
	
	LEA	EDI, outString	; set up for STOSB
	CLD

; if the number is negative
	CMP	isNegative, 1
	JNE	_convert
	MOV	AL, 45		; add '-' sign in front
	STOSB

_convert:
	POP	getStack	; get the remainder from stack(order reversed back)	
	MOV	AL, BYTE PTR getStack
	ADD	AL, 48		; restore the string value
	STOSB			; save the byte in EDI(outString)
	LOOP	_convert 
	MOV	AL, 0		; add 0 for null-terminated string
	STOSB
	
	LEA	EDX, outString
	mDisplayString	EDX	; display the outString

	POPAD
	RET	4
WriteVal	ENDP

END	main
