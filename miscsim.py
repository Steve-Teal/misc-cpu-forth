#
# MISC-16 Simulator
#

import msvcrt

class miscsim():

    CTRL_C = (3)

    def __init__(self):
        self.accu = 0        # Accumulator
        self.pc = 16         # Program Counter
        self.carry = False   # Carry Flag
        self.lastkey = 0
        self.memory = []
        self.memorysize = 32768
        self.key = 0

    def LoadFile(self,file):
        while True:
            word = file.read(2)
            if len(word) != 2:
                break
            self.memory.append((word[0] << 8) + (word[1] & 0xff))
        while len(self.memory) < self.memorysize:
            self.memory.append(0)

    def Read(self,address):
        if address == 0:
            return self.pc
        elif address == 1:
            return self.pc + 2
        elif address == 2:
            return self.pc + 4
        elif address == 3:
            return self.pc + 6
        elif address == 7:
            return self.Read(self.accu)
        elif address == 8:
            return self.accu
        elif address == 0xfffd:
            return 0
        elif address == 0xfffe:
            self.key = ord(msvcrt.getch())
            return self.key
        elif address == 0xffff:
            return int(msvcrt.kbhit())
        elif address < self.memorysize:
            return self.memory[address]
        else:
            return 0

    def Write(self,address,data):
        if address == 0:
            self.pc = data
        elif address == 1:
            if self.accu & 0x8000:
                self.pc = data # Take branch if accumulator sign bit is set
        elif address == 2:
            if self.accu == 0:
                self.pc = data # Take branch if accumulator is zero
        elif address == 4:
            if self.carry:
                self.pc = data # Take branch if carry flag is set
        elif address == 7:
            self.Write(self.accu,data)
        elif address == 8:
            self.accu = data
        elif address == 9:
            self.Sub(data)
        elif address == 11:
            self.Add(data)
        elif address == 12:
            self.accu = self.accu ^ data
        elif address == 13:
            self.accu = self.accu | data
        elif address == 14:
            self.accu = self.accu & data
        elif address == 15:
            self.ShiftRight(data)
        elif address == 0xfffc:
            if data <= 127 and data != 13:
                msvcrt.putch(bytes([data]))
        elif address <= self.memorysize:
            self.memory[address] = data

    def Add(self,data):
        self.accu = self.accu + data
        if self.accu & 0x10000:
            self.carry = 1            
        else:
            self.carry = 0
        self.accu &= 0xffff

    def Sub(self,data):
        self.accu = self.accu + (data ^ 0xffff) + 1
        if self.accu & 0x10000:
            self.carry = 0
        else:
            self.carry = 1
        self.accu &= 0xffff   

    def ShiftRight(self,data):
        self.accu = data >> 1
        if self.carry:
            self.accu |= 0x8000
        self.carry = data & 1

    def Run(self):
        self.pc = 0x10
        while self.key != self.CTRL_C:            
            src = self.Read(self.pc)
            dst = self.Read(self.pc+1)
            temp = self.Read(src)
            self.pc += 2
            self.Write(dst,temp)


   
