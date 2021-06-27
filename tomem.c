
#include<conio.h>
#include<stdlib.h>
#include<stdio.h>
#include<stdint.h>
#include<string.h>

void main(void)
{
    FILE *fp;
    int i;
    uint16_t ram[32768];
    int fs;

    fp = fopen("kernl-misc-0-7-3.fi","rb");
    fs = fread(ram,sizeof(uint16_t),32768,fp);
    
    for(i=0;i<fs;i++)
    {
        ram[i] = ram[i] >> 8 | ram[i] << 8;
    }

    if(fs > 1000)
    {
        fp = fopen("kernl-misc-0-7-3.mem","w");
        fprintf(fp, "#Depth=%d\n",fs);
        fprintf(fp, "#Width=16\n");
        fprintf(fp, "#AddrRadix=3\n");
        fprintf(fp, "#DataRadix=3\n");
        fprintf(fp, "#Data\n");
        for(i=0;i<fs;i++)
        {
            fprintf(fp, "%03X : %04X\n",i,ram[i]);
        }
        fprintf(fp, "# The end\n");
        fclose(fp);
        printf("MEM file created %d words.\n",fs);
    }
    fclose(fp);
}