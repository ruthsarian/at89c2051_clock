HOUR EQU 22H;时
MIN EQU 23H;分
SEC EQU 24H;秒
;20H:标志位   (20H).0:半秒到标志,(20H).1:当前第一位闪,(20H).2:当前第二位闪,(20H).3:当前第三位闪
              ;(20H).4:当前第四位闪,(20H).5:校时标志,(20H).6:校闹时标志,(20H).7:打闹标志
;21H:标志位   (21H).0:修改校时或闹时参数,(21H).1:闹时结束
;2AH:时暂存单元,2BH: 分暂存单元,3AH:闹时时存贮单元,3BH:闹时分存贮单元
;30H--35H:时,分,秒单个BCD码存贮单元
;***********************************
  ;主程序
;************************************
;显示时间,有键按下则处理按键,如果需要闹时闹时时间至则闹时一分钟

      ORG 0000H
      AJMP  LOOP
      ORG 000BH
      AJMP CLOCK;走时定时
      ORG 001BH
      AJMP CLOCK1M;打闹一分钟定时

LOOP: CALL ORG1;初始化
LOOP1:ACALL DISPLAY1; 调显示程序
      JB P3.4,LOP1; A键按了吗?
      ACALL AKEY
LOP1: JB P3.5,LOP2; B键按了吗?
      ACALL BKEY
LOP2: JB (21H).0,LOOP1;正在修改参数,不闹时
      JNB (20H).7,LOP3; 有打闹标志吗?没转
      JNB (21H).1,LOOP1; 停闹时吗？
      CLR TR1
      SETB P3.7
      CLR (20H).7
      CLR (21H).1
	  CLR (21H).2;
	  SETB P3.7
      SJMP LOOP1
LOP3: MOV A,22H; 闹时时间到吗?
      XRL A,3AH; 3AH,3BH比22H,23H
      JNZ LOOP1
      MOV A,23H
      XRL A,3BH
      JNZ LOOP1
      SETB (20H).7; 到了,置闹时标志
     ; CLR P3.7; 闹时输出
	 CLR (21H).2;
      SETB TR1
      SJMP LOOP1

;************************************
;显示程序
;**********************************
;(20H).0:半秒到标志
;当参数修改时,显示须产生位闪,闪动与秒闪同步,非参数修改时,位不闪,直接显示
;P3.0-P3.3:时分位控,0位显示,1位不显示
DISPLAY1:ACALL BCDCH
        JNB (20H).1,BIT1;jump BIT1
        JNB (20H).0,BIT1;jump BIT1
        SETB P3.3
        SJMP BIT2
BIT1:   MOV A,30H
        ;SWAP A
        ;ANL P1,#01H
		 MOV   DPTR,#TAB_LED
          MOVC  A,@A+DPTR
         MOV    P1,A
        ORL P1,A
        SETB P3.3

        CLR P3.0
        ACALL DELAY
        JNB (20H).2,BIT2
        JNB (20H).0,BIT2
        SETB P3.0
        SJMP BIT3
BIT2:   MOV A,31H
        ;SWAP A
        ;ANL P1,#01H
		 MOV   DPTR,#TAB_LED
          MOVC  A,@A+DPTR
         MOV    P1,A
        ORL P1,A
        SETB P3.0

        CLR P3.1
        ACALL DELAY
        JNB (20H).3,BIT3
        JNB (20H).0,BIT3
        SETB P3.1
        SJMP BIT4
BIT3:   MOV A,32H
        ;SWAP A
       ;ANL P1,#01H
		 MOV   DPTR,#TAB_LED
          MOVC  A,@A+DPTR
         MOV    P1,A
        ORL P1,A
        SETB P3.1

        CLR P3.2
        ACALL DELAY
        JNB (20H).4,BIT4
        JNB (20H).0,BIT4
        SETB P3.2
        SJMP SEC1
BIT4:   MOV A,33H
        ;SWAP A
        ;ANL P1,#01H
		 MOV   DPTR,#TAB_LED
          MOVC  A,@A+DPTR
          MOV    P1,A
        ORL P1,A
        SETB P3.2

        CLR P3.3
        ACALL DELAY
		 SETB P3.3
        ;SJMP BIT2

 SEC1:  JB (20H).5,DD0;校时修改秒显常亮
        JB (20H).6,DD1;闹时修改秒显不亮
        JB (20H).0,DD1;走时闪
 DD0:    MOV A,#0AH
         ;ANL P1,#01H
		 MOV   DPTR,#TAB_LED
          MOVC  A,@A+DPTR
          MOV    P1,A
		  ORL P1,A
 		  ACALL DELAY1
        RET
 DD1:  SETB P1.0
  
        RET
        
 ;********************************
 ;初始化程序
 ;******************************       
        
ORG1:   MOV 20H,#00H
        MOV 21H,#00H
        MOV 22H,#12H;置走时初值
        MOV 23H,#00H
        MOV 24H,#00H
		MOV 25H,#03H
        MOV 3AH,#06H;置闹时初值
        MOV 3BH,#01H
        MOV TMOD,#11H
        MOV TH0,#3CH
        MOV TL0,#0B5H;加了5uS
	  MOV TL1,#0CAH
      MOV TH1,#0FEH
        MOV R4,#255
        MOV R5,#255
        MOV R6,#20;一秒当量
        SETB EA
        SETB ET0
        SETB TR0
        SETB ET1
        SETB PT0
        RET

;***********************************
;定时中断0
;*********************************
;走时时间处理程序
;*******************************        

CLOCK:MOV TL0,#0C5H;#0B5H	;数据已修正过慢5uS
      MOV TH0,#3CH
      PUSH ACC
      PUSH PSW
      DJNZ R6,ENDT0;1秒未到转
      SJMP PPP
ENDT0:CLR C;断是否到半秒
      MOV A,#10
      SUBB A, R6
      JC ENDT
      SETB (20H).0
      SJMP ENDT
 PPP: CLR (20H).0
      MOV R6,#20
      MOV A,SEC
      INC A
      DA A
      MOV SEC,A
      ;JB P3.7,PPP1
      ;CJNE A,#01H,ENDT
      ;SJMP PPP2
PPP1: CJNE A,#60H,ENDT
PPP2: MOV SEC,#00; 60 SEC arrive MIN increase 1
      MOV A,MIN
      INC A
      DA A
      MOV MIN,A
      CJNE A,#60H,ENDT
      MOV MIN,#00H; 60 MIN arrive HOUR increase 1
      MOV A,HOUR
      INC A
      DA A
      MOV HOUR,A
      CJNE A,#24H,ENDT
      MOV HOUR,#00H
 ENDT:POP PSW
      POP ACC
      RETI
      
;***************************
;中断程序1
;***************************
;打闹一分钟定时
;(21H).1:一分时间到标志
      
CLOCK1M:

	MOV TL1,#0CAH
      MOV TH1,#0FEH
	   	JB (21H).2,CK2M; 停闹时吗？
		CPL P3.7

CK2M: DJNZ R5,CK1M
      MOV R5,#255;一分钟常量

      DJNZ R4,CK1M
	  DJNZ 25H,CK1M
	  MOV 25H,#03H;一分钟常量
	  SETB (21H).1;
CK1M: RETI

;******************************
;延时子程序
;******************************

DEL:  MOV R2,#0A0H
      SJMP DE2
DELAY:NOP
  DE1:MOV   R2, #01H
  DE2:MOV   R1, #0FFH
  DE3:MOV   R0, #03H
  DE4:DJNZ  R0, DE4
      DJNZ  R1, DE3
      DJNZ  R2, DE2
      RET
 
 DEL1:  MOV R2,#040H
      SJMP DE21
DELAY1:NOP
  DE11:MOV   R2, #01H
  DE21:MOV   R1, #055H
  DE31:MOV   R0, #02H
  DE41:DJNZ  R0, DE41
      DJNZ  R1, DE31
      DJNZ  R2, DE21
      RET
  DEL2:  MOV R2,#01H
      SJMP DE22
DELAY2:NOP
  DE12:MOV   R2, #01H
  DE22:MOV   R1, #088H
  DE32:MOV   R0, #03H
  DE42:DJNZ  R0, DE42
      DJNZ  R1, DE32
      DJNZ  R2, DE22
      RET
 
 
      
;*****************************
;复合BCD码转单字节BCD码
;****************************
;(20H).6:闹时标志
;30H-35H:时分秒单字节BCD码存放单元
;3AH,3BH:打闹时间存放单元

BCDCH:JNB (20H).6,BCD1
      MOV A,3AH
      SJMP BCD2
 BCD1:MOV A,HOUR
 BCD2:MOV R7,A
      MOV R1,#30H
      ANL A,#0F0H
      SWAP A
      MOV @R1,A
      INC R1
      MOV A,R7
      ANL A,#0FH
      MOV @R1,A
      INC R1
      JNB (20H).6,BCD3
      MOV A,3BH
      SJMP BCD4
BCD3: MOV A, MIN
BCD4: MOV R7,A
      ANL A,#0F0H
      SWAP A
      MOV @R1,A
      INC R1
      MOV A,R7
      ANL A,#0FH
      MOV @R1,A
      INC R1
      MOV A,SEC
      ANL A,#0F0H
      SWAP A
      MOV @R1,A
      INC R1
      MOV A, SEC
      ANL A,#0FH
      MOV @R1,A
      RET
      
;*******************************
;A键处理程序
;****************************
;作用:修改参数时移位
AKEY: JNB P3.4,AKEY;去抖
      CALL DEL
      JB (20H).5,BB1; 修改校时转
      JB (20H).6,BB1; 修改闹时转
      ;CLR TR1
      SETB P3.7
	  CLR (21H).1      
      SETB (21H).2	  
      SETB P3.7; 止闹

      RET
BB1:  SETB (21H).0; 置校闹时修改标志
      JB (20H).1,BB2; 第一位闪转
      JB (20H).2,BB3; 第二位闪转
      JB (20H).3,BB4; 第三位闪转
      JB (20H).4,BC1; 第四位闪转
      SETB (20H).1; 置第一位闪
      RET
 BC1: CLR (20H).4;清第四位修改标志
      CLR (21H).0
      CLR (20H).5
      CLR (20H).6
      RET
 BB2: CLR (20H).1; 置第二位闪标志
      SETB (20H).2
      RET
 BB3: CLR (20H).2; 置第三位闪标志
      SETB (20H).3
      RET
 BB4: CLR (20H).3; 置第四位闪标志
      SETB (20H).4
      RET

;************************************
;B键处理程序
;***********************************
;作用:校时闹时走时转换,参数修改
;作参数修改时,必须先按A键,出现位闪动
BKEY: JNB P3.5,BKEY; 去抖
      ACALL DEL
	  
      JNB (21H).0,BKEY1; 无修改标志转
      ACALL MODY
      RET
 BKEY1: JB (20H).5,BKEY2; 是校时参数修改转
      JB (20H).6,BKEY3; 是闹时参数修改转
      SETB (20H).5
      RET
 BKEY2: SETB (20H).6
      CLR (20H).5
      RET
 BKEY3: CLR (20H).6
      RET

MODY: JB (20H).1,BK1;第一位修改转
      JB (20H).2,BK2;第二位修改转
      JB (20H).3,BK3;第三位修改转
      MOV A,33H; 第四位修改
      MOV R7,A
      CALL MOD09
      MOV 33H,R7
  BK0:NOP
      MOV A, 30H; 修改值置缓冲区
      SWAP A
      ORL A,31H
      MOV 2AH,A
      MOV A,32H
      SWAP A
      ORL A,33H
      MOV 2BH,A
      JB (20H).5,BK
      JB (20H).6,BK4
      RET
BK:   MOV HOUR,2AH
      MOV MIN, 2BH
      RET
BK4:  MOV 3AH,2AH
      MOV 3BH,2BH
      RET
BK1:  MOV A, 30H  ; 第一位修改
      MOV R7,A
      XRL A,#09H
     JNZ KK1
      MOV 30H,#00H
      SJMP BK0
KK1:  INC R7
      MOV 30H,R7
      SJMP BK0
BK2:  MOV A,31H; 第二位修改
      MOV R7,A
      CALL MOD09
      MOV 31H,R7
      SJMP BK0
BK3:  MOV A,32H; 第三位修改
      MOV R7,A
      XRL A,#06H
      JNZ MM1
      MOV 32H,#00H
      SJMP BK0
MM1:  INC R7
      MOV 32H,R7
      SJMP BK0
      
      
MOD09:XRL A,#09H;数字0-9变化
      JNZ NN1
      MOV R7,#00H
      RET
 NN1: INC R7
      RET
TAB_LED:     DB 0FDH,25H,0BBH,0AFH,67H,0CFH,0DFH;共阴字码表
             DB 0A5H,0FFH,0EFH,0FEH

END
