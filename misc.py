import sys
import miscsim
import miscasm

def filename(extension):
    ignore = True
    for arg in sys.argv:
        if not ignore and len(arg) > 4:
            if arg[-4:].lower() == extension.lower():
                return arg
        ignore = False
    return ""

def makemif(filename,image,length):
    try:
        file = open(filename,'wt')
    except IOError:
        print("Failed to open output file {:s}".format(filename))
        sys.exit()

    # Write header to file
    file.write("DEPTH = {:d};\n".format(length))
    file.write("WIDTH = 16;\n")
    file.write("ADDRESS_RADIX = HEX;\n")
    file.write("DATA_RADIX = HEX;\n")
    file.write("CONTENT\nBEGIN\n")

    # Write data
    for address in range(0,length):
        file.write("{:03X} : {:04X} ;\n".format(address,image[address]))

    # End and close file
    file.write("END\n")
    file.close()
    print("MIF file {:s} created".format(filename))

def makebin(filename,image,length):
    try:
        file = open(filename,'wb')
    except IOError:
        print("Failed to open output file {:s}".format(filename))
        sys.exit()
    for address in range(0,length):
        file.write(bytes([image[address]>>8,image[address]&0xff]))
    file.close()
    print("BIN file {:s} created".format(filename))


if __name__ == "__main__":

    # Extract filenames from command line arguments    
    sourcefile = filename(".asm")
    binfile = filename(".bin")
    miffile = filename(".mif")
    lstfile = filename(".lst")

    # Display usage if no source file specified
    if not sourcefile:
        print("Usage: python misc.py <input.asm> [out.mif][out.bin][out.lst]")
        sys.exit()

    # Open source file
    try:
        file = open(sourcefile,"rt")
    except IOError:
        print("Could not open file {:s}".format(sourcefile))
        sys.exit()

    # Assemble file
    asm = miscasm.miscasm(file)
    file.close()

    # Bail out if we have errors
    if asm.errorcount != 0:
        print("Assembly failed with {:d} errors".format(asm.errorcount))
        sys.exit()

    # Success
    print("Success: assembly completed {:d} bytes".format(asm.memoryindex<<1))

    # Generate FPGA file
    if miffile:
        makemif(miffile,asm.image,asm.memoryindex)

    # Generate BIN file
    if binfile:
        makebin(binfile,asm.image,asm.memoryindex)

    if not (miffile or binfile or lstfile):

        sim = miscsim.miscsim()
        sim.memory = asm.image
        while(len(sim.memory) < 32768):
            sim.memory.append(0)
        sim.Run()

