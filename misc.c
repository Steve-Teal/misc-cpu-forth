/*
    Fairweather 'C' implementation of a MISC (Minimal Instruction Set CPU) virtual machine
    with a GForth kernel. This program is unlikely to run or compile on a non-Windows machine.
    It can be built with the GCC compiler as follows:

        gcc misc.c -o misc.exe

    MIT License
    Copyright (c) 2021 Steve Teal
*/

#include<conio.h>
#include<stdlib.h>
#include<stdio.h>
#include<stdint.h>
#include<string.h>

#define RAM_SIZE    (32768)

uint16_t ram[RAM_SIZE];
uint16_t accu;
uint16_t sf;
uint16_t zf;
uint16_t cf;
uint16_t pc;

void loadfile(char *fileName)
{
    FILE *fp;
    int index;

    memset(ram,0,sizeof(ram));
    fp = fopen(fileName,"rb");
    fread(ram,sizeof(uint16_t),RAM_SIZE,fp);
    fclose(fp);
    for(index=0;index<RAM_SIZE;index++)
    {
        ram[index] = ram[index] >> 8 | ram[index] << 8;
    }
}

void writeAccu(uint16_t value)
{
    accu = value;
    sf = value&0x8000?1:0;
    zf = value?0:1;
}

uint16_t read(uint16_t address)
{
    switch(address)
    {
        case 0: return pc;
        case 1: return pc + 2;
        case 2: return pc + 4;
        case 3: return pc + 6;
        case 8: return accu;
        case 9: return sf;
        case 10: return zf;
        case 12: return cf;
        case 0xfffa: return getch()&0xff;
        case 0xfffb: return kbhit()?7:5;
        default: break;
    }

    return address<RAM_SIZE?ram[address]:0;
}

uint16_t sub(uint16_t a, uint16_t b)
{
    uint16_t s;

    b = ~b;
    s = a + b + 1;
    cf = (((a&b)|((a|b)&~s))&0x8000)?0:1;
    return s;
}

uint16_t add(uint16_t a, uint16_t b)
{
    uint16_t s;

    s = a + b;
    cf = (((a&b)|((a|b)&~s))&0x8000)?1:0;
    return s;
}

uint16_t shiftright(uint16_t a)
{
    uint16_t s;

    s = a >> 1 | cf << 15;
    cf = a & 1;
    return s;
}

void write(uint16_t address, uint16_t data)
{
    switch(address)
    {
        case 0: pc = data; return;
        case 1: pc = sf?data:pc; return;
        case 2: pc = zf?data:pc; return;
        case 4: pc = cf?data:pc; return;
        case 8: writeAccu(data); return;
        case 9: writeAccu(sub(accu,data)); return;
        case 10: writeAccu(sub(data,accu)); return;
        case 11: writeAccu(add(data,accu)); return;
        case 12: writeAccu(data ^ accu); return;
        case 13: writeAccu(data | accu); return;
        case 14: writeAccu(data & accu); return;
        case 15: writeAccu(shiftright(data)); return;
        case 0xfffc: putch(data&0xff); return;
        default: break;
    }

    if(address<RAM_SIZE)
    {
        ram[address] = data;
    }
}

int main(void)
{
    uint16_t src;
    uint16_t dst;
    uint16_t temp;

    loadfile("kernel.bin");
    pc = 0x10; /* Program counter reset value */
    while(1)
    {
        src = ram[pc];
        dst = ram[pc+1];
        temp = read(src);
        pc+=2;
        write(dst,temp);
    }
}

/* End of file */

