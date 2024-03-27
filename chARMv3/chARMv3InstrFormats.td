//===- chARMv3InstrFormats.td - chARMv3 Instruction Formats --*- tblgen -*-===//
//===- All instructions are 32 bit wide. ----------------------------------===//

//===----------------------------------------------------------------------===//
// Formats in chARMv3
//===----------------------------------------------------------------------===//
class Format<bits<4> val> {
    bits<4> Value = val;
}
def format_M  : Format<0>;
def format_M2 : Format<1>;
def format_I1 : Format<2>;
def format_I2 : Format<3>;

def format_RC : Format<4>;
def format_RR : Format<5>;
def format_RI : Format<6>;

def format_B1 : Format<7>;
def format_B2 : Format<8>;
def format_B3 : Format<9>;

def format_S  : Format<10>;

// Generic chARMv3 instruction format 
// Note (Namish): is it worth codifying the difference between pseudo instructions 
//                (we only have one, NOP) and regular instructions?
class chARMInst<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin, Format f,
                : Instruction> 
{
    // need Inst and Size for tablegen
    field bits<32> Inst;
    Format Form = f.Value;

    let Namespace = "chARMv3";
    let Size = 4;

    let AsmString   = asmstr;
    let Pattern     = pattern;
    let Itinerary   = itin;
    
    // Note (Namish): Not entirely sure what this is, but it's present in AArch64InstrInfo and
    // CPU0InstrInfo. I'm going to keep it there.
    let TSFlags{3-0} = f.Value;

    field bits<32> SoftFail = 0; // no idea what this does ... they have a desc in AArch64InstrFormats
}

//===----------------------------------------------------------------------===//
// M Format instruction class in chARMv3 : 
//===----------------------------------------------------------------------===//
class M<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin>
          : chARMInst<oops, iops, asmstr, pattern, itin, format_RI>
{
    bits<11> op;
    bits<9> simm9;
    bits<5> Rn;
    bits<5> Rd;

    let Inst{31-21} = op;
    let Inst{20-12} = simm9;
    let Inst{11-10} = 0;
    let Inst{9-5} = Rn;
    let Inst{4-0} = Rd;
}

//===----------------------------------------------------------------------===//
// M2 Format instruction class in chARMv3 : 
//===----------------------------------------------------------------------===//
class M2<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin>
          : chARMInst<oops, iops, asmstr, pattern, itin, format_RI>
{
    bits<10> op;
    bits<9> simm7;
    bits<5> Rt2;
    bits<5> Rn;
    bits<5> Rd;

    let Inst{31-22} = op;
    let Inst{21-15} = simm9;
    let Inst{14-10} = Rt2;
    let Inst{9-5} = Rn;
    let Inst{4-0} = Rd;
}

//===----------------------------------------------------------------------===//
// I1 Format instruction class in chARMv3 : 
//===----------------------------------------------------------------------===//
class I1<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin>
          : chARMInst<oops, iops, asmstr, pattern, itin, format_RI>
{
    bits<9> op;
    bits<2> hw;
    bits<16> imm16;
    bits<5> Rd;

    let Inst{31-23} = op;
    let Inst{22-21} = hw;
    let Inst{20-5} = imm16;
    let Inst{4-0} = Rd;
}

//===----------------------------------------------------------------------===//
// I2 Format instruction class in chARMv3 : 
//===----------------------------------------------------------------------===//
class I2<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin>
          : chARMInst<oops, iops, asmstr, pattern, itin, format_RI>
{
    bits<8> op;
    bits<19> simm19;
    bits<5> Rd;

    let Inst{31-24} = op;
    let Inst{23-5} = simm19;
    let Inst{4-0} = Rd;
}

//===----------------------------------------------------------------------===//
// RC Format instruction class in chARMv3 : 
//===----------------------------------------------------------------------===//
class RC<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin>
          : chARMInst<oops, iops, asmstr, pattern, itin, format_RI>
{
    bits<8> op;
    bits<5> Rm;
    bits<4> cond;
    bits<5> Rn;
    bits<5> Rd;

    let Inst{31-24} = op;
    let Inst{23-21} = 0;
    let Inst{20-16} = Rm;
    let Inst{15-12} = cond;
    let Inst{11-10} = 0;
    let Inst{9-5} = Rn;
    let Inst{4-0} = Rd;
}

//===----------------------------------------------------------------------===//
// RR Format instruction class in chARMv3 : 
//===----------------------------------------------------------------------===//
class RR<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin>
          : chARMInst<oops, iops, asmstr, pattern, itin, format_RI>
{
    bits<8> op;
    bits<5> Rm;
    bits<5> Rn;
    bits<5> Rd;

    let Inst{31-24} = op;
    let Inst{23-21} = 0;
    let Inst{20-16} = Rm;
    let Inst{15-10} = 0;
    let Inst{9-5} = Rn;
    let Inst{4-0} = Rd;
}

//===----------------------------------------------------------------------===//
// RI Format instruction class in chARMv3 : 
//===----------------------------------------------------------------------===//
class RI<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin>
          : chARMInst<oops, iops, asmstr, pattern, itin, format_RI>
{
    bits<9> op;
    bits<12> imm12;
    bits<5> Rn;
    bits<5> Rd;

    let Inst{31-23} = op;
    let Inst{21-10} = imm12;
    let Inst{9-5} = Rn;
    let Inst{4-0} = Rd;
}

//===----------------------------------------------------------------------===//
// B1 Format instruction class in chARMv3 : 
//===----------------------------------------------------------------------===//
class B1<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin>
          : chARMInst<oops, iops, asmstr, pattern, itin, format_RI>
{
    bits<6> op;
    bits<26> simm26;

    let Inst{31-26} = op;
    let Inst{25-0} simm26;
}

//===----------------------------------------------------------------------===//
// B2 Format instruction class in chARMv3 : 
//===----------------------------------------------------------------------===//
class B2<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin>
          : chARMInst<oops, iops, asmstr, pattern, itin, format_RI>
{
    bits<8> op;
    bits<19> simm19;
    bits<4> cond;

    let Inst{31-24} = op;
    let Inst{23-5} simm26;
    let Inst{4} = 0;
    let Inst{3-0} = cond;
}

//===----------------------------------------------------------------------===//
// B3 Format instruction class in chARMv3 : 
//===----------------------------------------------------------------------===//
class B3<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin>
          : chARMInst<oops, iops, asmstr, pattern, itin, format_RI>
{
    bits<11> op;
    bits<5> Rn;

    let Inst{31-21} = op;
    let Inst{20-10} = 1984; // 0b11111000000
    let Inst{9-5} = Rn;
    let Inst{4-0} = 0;
}

//===----------------------------------------------------------------------===//
// S Format instruction class in chARMv3 : 
//===----------------------------------------------------------------------===//
class S<dag oops, dag iops, string asmstr, list<dag> pattern, InstrItinClass itin>
          : chARMInst<oops, iops, asmstr, pattern, itin, format_RI>
{
    bits<11> op;

    let Inst{31-21} = op;
    // the rest doesn't matter
}
