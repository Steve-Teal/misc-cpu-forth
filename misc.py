import sys
import miscsim
import miscasm

if __name__ == "__main__":
    # if len(sys.argv) < 3 or len(sys.argv) > 4:
    #     print("Usage: python assembler.py <source file> <output file> [listing file]")
    #     sys.exit()

    # Assemble file
    file = open(sys.argv[1])
    asm = miscasm.miscasm(file)
    file.close()

    # Bail out if we have any errors
    if asm.errorcount != 0:
        print("Assembly failed with {:d} errors".format(asm.errorcount))
        sys.exit()

    print("Success: assembly completed {:d} bytes".format(asm.memoryindex<<1))
    sim = miscsim.miscsim()

    sim.memory = asm.image

    while(len(sim.memory) < 32768):
        sim.memory.append(0)

    sim.Run()

