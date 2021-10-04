import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'image.dart';
import 'maths.dart';
import 'fileloader.dart';

//Config
var imageDirectory = './images/P04_02_animation';
var videoDirectory = './images/test.mpeg';
var numFrames = 48;
var frameRate = 24;

// original: https://github.com/yui0/slibs/blob/master/jo_mpeg.h

// modified: Dr. Jon Denning
// author: Tim Swanson

// Only supports 24, 25, 30, 50, or 60 fps

// Huffman tables for RLE encoding

// https://en.wikipedia.org/wiki/MPEG-1#Entropy_coding

const s_jo_HTDC_Y = [
  [4, 3],
  [0, 2],
  [1, 2],
  [5, 3],
  [6, 3],
  [14, 4],
  [30, 5],
  [62, 6],
  [126, 7]
];
const s_jo_HTDC_C = [
  [0, 2],
  [1, 2],
  [2, 2],
  [6, 3],
  [14, 4],
  [30, 5],
  [62, 6],
  [126, 7],
  [254, 8]
];
const s_jo_HTAC = [
  [
    [6, 3],
    [8, 5],
    [10, 6],
    [12, 8],
    [76, 9],
    [66, 9],
    [20, 11],
    [58, 13],
    [48, 13],
    [38, 13],
    [32, 13],
    [52, 14],
    [50, 14],
    [48, 14],
    [46, 14],
    [62, 15],
    [62, 15],
    [58, 15],
    [56, 15],
    [54, 15],
    [52, 15],
    [50, 15],
    [48, 15],
    [46, 15],
    [44, 15],
    [42, 15],
    [40, 15],
    [38, 15],
    [36, 15],
    [34, 15],
    [32, 15],
    [48, 16],
    [46, 16],
    [44, 16],
    [42, 16],
    [40, 16],
    [38, 16],
    [36, 16],
    [34, 16],
    [32, 16],
  ],
  [
    [6, 4],
    [12, 7],
    [74, 9],
    [24, 11],
    [54, 13],
    [44, 14],
    [42, 14],
    [62, 16],
    [60, 16],
    [58, 16],
    [56, 16],
    [54, 16],
    [52, 16],
    [50, 16],
    [38, 17],
    [36, 17],
    [34, 17],
    [32, 17]
  ],
  [
    [10, 5],
    [8, 8],
    [22, 11],
    [40, 13],
    [40, 14]
  ],
  [
    [14, 6],
    [72, 9],
    [56, 13],
    [38, 14]
  ],
  [
    [12, 6],
    [30, 11],
    [36, 13]
  ],
  [
    [14, 7],
    [18, 11],
    [36, 14]
  ],
  [
    [10, 7],
    [60, 13],
    [40, 17]
  ],
  [
    [8, 7],
    [42, 13]
  ],
  [
    [14, 8],
    [34, 13]
  ],
  [
    [10, 8],
    [34, 14]
  ],
  [
    [78, 9],
    [32, 14]
  ],
  [
    [70, 9],
    [52, 17]
  ],
  [
    [68, 9],
    [50, 17]
  ],
  [
    [64, 9],
    [48, 17]
  ],
  [
    [28, 11],
    [46, 17]
  ],
  [
    [26, 11],
    [44, 17]
  ],
  [
    [16, 11],
    [42, 17]
  ],
  [
    [62, 13]
  ],
  [
    [52, 13]
  ],
  [
    [50, 13]
  ],
  [
    [46, 13]
  ],
  [
    [44, 13]
  ],
  [
    [62, 14]
  ],
  [
    [60, 14]
  ],
  [
    [58, 14]
  ],
  [
    [56, 14]
  ],
  [
    [54, 14]
  ],
  [
    [62, 17]
  ],
  [
    [60, 17]
  ],
  [
    [58, 17]
  ],
  [
    [56, 17]
  ],
  [
    [54, 17]
  ],
];
const s_jo_quantTbl = [
  0.015625,
  0.005632,
  0.005035,
  0.004832,
  0.004808,
  0.005892,
  0.007964,
  0.013325,
  0.005632,
  0.004061,
  0.003135,
  0.003193,
  0.003338,
  0.003955,
  0.004898,
  0.008828,
  0.005035,
  0.003135,
  0.002816,
  0.003013,
  0.003299,
  0.003581,
  0.005199,
  0.009125,
  0.004832,
  0.003484,
  0.003129,
  0.003348,
  0.003666,
  0.003979,
  0.005309,
  0.009632,
  0.005682,
  0.003466,
  0.003543,
  0.003666,
  0.003906,
  0.004546,
  0.005774,
  0.009439,
  0.006119,
  0.004248,
  0.004199,
  0.004228,
  0.004546,
  0.005062,
  0.006124,
  0.009942,
  0.008883,
  0.006167,
  0.006096,
  0.005777,
  0.006078,
  0.006391,
  0.007621,
  0.012133,
  0.016780,
  0.011263,
  0.009907,
  0.010139,
  0.009849,
  0.010297,
  0.012133,
  0.019785,
];

// see http://www.bretl.com/mpeghtml/zigzag.HTM

const s_jo_ZigZag = [
  0,
  1,
  5,
  6,
  14,
  15,
  27,
  28,
  2,
  4,
  7,
  13,
  16,
  26,
  29,
  42,
  3,
  8,
  12,
  17,
  25,
  30,
  41,
  43,
  9,
  11,
  18,
  24,
  31,
  40,
  44,
  53,
  10,
  19,
  23,
  32,
  39,
  45,
  52,
  54,
  20,
  22,
  33,
  38,
  46,
  51,
  55,
  60,
  21,
  34,
  37,
  47,
  50,
  56,
  59,
  61,
  35,
  36,
  48,
  49,
  57,
  58,
  62,
  63,
];

// wrapper for put1b, put4b, put8b, bufferBits

class BitWriter {
  List<int> _data = [];
  int _bitbuf = 0, _bitcnt = 0;
  Uint8List getData() {
    flushBufferedBits();
    return Uint8List.fromList(_data);
  }

  void bufferBits(int value, int count) {
    // copied from https://github.com/yui0/slibs/blob/master/jo_mpeg.h#L109
    // 3 2         1         0
    // 10987654321098765432109876543210
    // 00000000000000000000000000000000
    // 00000000a00000000000000000000000  bitcnt = 0, count = 1, 24-(0+1) = 23
    // 00000000ab0000000000000000000000  bitcnt = 1, count = 1, 24-(1+1) = 22
    // 00000000abcc00000000000000000000  bitcnt = 2, count = 2, 24-(2+2) = 20
    // 00000000abccddddd000000000000000  bitcnt = 4, count = 5, 24-(4+5) = 15
    // XXXXXXXXabccdddd                  >> 16 & 255
    // 00000000d00000000000000000000000  bitcnt = 1
    // ^       ^       ^
    // |       |       + these are 2 additional bytes for temp buffering
    // |       + this 1byte is written once >=8bits are buffered
    // + this 1byte is always 0
    // once >=8bits are buffered, the byte is written out (can repeat if >=16bits are buffered)
    // when this function returns, there will be between 0--7bits left in buffer
    value &= (1 << count) - 1;
    _bitcnt += count;
    _bitbuf |= value << (24 - _bitcnt);
    while (_bitcnt >= 8) {
      var c = (_bitbuf >> 16) & 255;
      _data.add(c);
      _bitbuf <<= 8;
      _bitcnt -= 8;
    }
  }

  void flushBufferedBits() {
    // flushes out any remaining buffered bits
    if (_bitcnt == 0) return; // nothing currently buffered
    _data.add((_bitbuf >> 16) & 255);
    _bitbuf = 0;
    _bitcnt = 0;
  }

  void putBits(List bits) {
    // assuming bits is multiple of 8
    flushBufferedBits();

    int buf = 0;
    int count = 0;
    for (int bit in bits) {
      buf = (buf << 1) | bit;
      count += 1;
      if (count == 8) {
        put1B(buf);
        buf = 0;
        count = 0;
      }
    }
    assert(count == 0);
  }

  void put1B(int v) {
    flushBufferedBits();
    _data.add(v);
  }

  void put4B(int c0, int c1, int c2, int c3) {
    flushBufferedBits();
    _data.add(c0);
    _data.add(c1);
    _data.add(c2);
    _data.add(c3);
  }

  void put8B(int c0, int c1, int c2, int c3, int c4, int c5, int c6, int c7) {
    flushBufferedBits();
    _data.add(c0);
    _data.add(c1);
    _data.add(c2);
    _data.add(c3);
    _data.add(c4);
    _data.add(c5);
    _data.add(c6);
    _data.add(c7);
  }
}

void jo_DCT(List<double> A, int d0, int d1, int d2, int d3, int d4, int d5,
    int d6, int d7) {
  double tmp0 = A[d0] + A[d7];
  double tmp7 = A[d0] - A[d7];
  double tmp1 = A[d1] + A[d6];
  double tmp6 = A[d1] - A[d6];
  double tmp2 = A[d2] + A[d5];
  double tmp5 = A[d2] - A[d5];
  double tmp3 = A[d3] + A[d4];
  double tmp4 = A[d3] - A[d4];

  // Even part
  double tmp10 = tmp0 + tmp3; // phase 2
  double tmp13 = tmp0 - tmp3;
  double tmp11 = tmp1 + tmp2;
  double tmp12 = tmp1 - tmp2;

  A[d0] = tmp10 + tmp11; // phase 3
  A[d4] = tmp10 - tmp11;

  double z1 = (tmp12 + tmp13) * 0.707106781; // c4
  A[d2] = tmp13 + z1; // phase 5
  A[d6] = tmp13 - z1;

  // Odd part
  tmp10 = tmp4 + tmp5; // phase 2
  tmp11 = tmp5 + tmp6;
  tmp12 = tmp6 + tmp7;

  // The rotator is modified from fig 4-8 to avoid extra negations.
  double z5 = (tmp10 - tmp12) * 0.382683433; // c6
  double z2 = tmp10 * 0.541196100 + z5; // c2-c6
  double z4 = tmp12 * 1.306562965 + z5; // c2+c6
  double z3 = tmp11 * 0.707106781; // c4

  double z11 = tmp7 + z3; // phase 5
  double z13 = tmp7 - z3;

  A[d5] = z13 + z2; // phase 6
  A[d3] = z13 - z2;
  A[d1] = z11 + z4;
  A[d7] = z11 - z4;
}

int jo_processDU(BitWriter bits, List A, List htdc, int DC) {
  for (int dataOff = 0; dataOff < 64; dataOff += 8) {
    jo_DCT(A, dataOff, dataOff + 1, dataOff + 2, dataOff + 3, dataOff + 4,
        dataOff + 5, dataOff + 6, dataOff + 7);
  }
  for (int dataOff = 0; dataOff < 8; ++dataOff) {
    jo_DCT(A, dataOff, dataOff + 8, dataOff + 16, dataOff + 24, dataOff + 32,
        dataOff + 40, dataOff + 48, dataOff + 56);
  }
  List Q = List<int>(64);
  for (int i = 0; i < 64; ++i) {
    double v = A[i] * s_jo_quantTbl[i];
    Q[s_jo_ZigZag[i]] = (v < 0 ? (v - 0.5).ceil() : (v + 0.5).floor());
  }

  DC = Q[0] - DC;
  int aDC = DC < 0 ? -DC : DC;
  int size = 0;
  int tempval = aDC;
  while (tempval != 0) {
    size++;
    tempval >>= 1;
  }
  bits.bufferBits(htdc[size][0], htdc[size][1]);
  if (DC < 0) {
    aDC ^= (1 << size) - 1;
  }
  bits.bufferBits(aDC, size);

  int endpos = 63;
  for (; (endpos > 0) && (Q[endpos] == 0); --endpos) {
    /* do nothing */
  }
  for (int i = 1; i <= endpos;) {
    int run = 0;
    while (Q[i] == 0 && i < endpos) {
      ++run;
      ++i;
    }
    int AC = Q[i++];
    int aAC = AC < 0 ? -AC : AC;
    int code = 0, size = 0;
    if (run < 32 && aAC <= 41) {
      if ((aAC - 1) < s_jo_HTAC[run].length) {
        //DC 1
        code = s_jo_HTAC[run][aAC - 1][0];
        size = s_jo_HTAC[run][aAC - 1][1];
        if (AC < 0) {
          code += 1;
        }
      }
    }
    if (size == 0) {
      bits.bufferBits(1, 6);
      bits.bufferBits(run, 6);
      if (AC < -127) {
        bits.bufferBits(128, 8);
      } else if (AC > 127) {
        bits.bufferBits(0, 8);
      }
      code = AC & 255;
      size = 8;
    }
    bits.bufferBits(code, size);
  }
  bits.bufferBits(2, 2);

  return Q[0];
}

void encode_mpeg(BitWriter mem, var rgbx, int width, int height, int fps) {
  int lastDCY = 128, lastDCCR = 128, lastDCCB = 128;
  BitWriter bits = mem;

  mem.put8B(0x00, 0x00, 0x01, 0xB8, 0x80, 0x08, 0x00, 0x40); // GOP header
  mem.put8B(0x00, 0x00, 0x01, 0x00, 0x00, 0x0C, 0x00, 0x00); // PIC header
  mem.put4B(0x00, 0x00, 0x01, 0x01); // Slice header
  mem.bufferBits(0x10, 6);

  for (int vblock = 0; vblock < (height / 16.0).ceil(); vblock++) {
    for (int hblock = 0; hblock < (width / 16).ceil(); hblock++) {
      mem.bufferBits(3, 2);

      // List Y, CBx, CRx;
      List Y = List<double>(256);
      List CBx = List<double>(256);
      List CRx = List<double>(256);

      for (int i = 0; i < 256; ++i) {
        int y = vblock * 16 + (i ~/ 16); //.floor was added
        int x = hblock * 16 + (i & 15);
        x = x >= width ? width - 1 : x;
        y = y >= height ? height - 1 : y;
        //const unsigned char *c = rgbx + y*width*4+x*4;
        var c = rgbx.getPixel(x, y);
        // var c = pixel + y*width*3+x*3;
        double r = c.redAsInt().toDouble(),
            g = c.greenAsInt().toDouble(),
            b = c
                .blueAsInt()
                .toDouble(); // todo, was I supposed to remove math?
        Y[i] = (0.59 * r + 0.30 * g + 0.11 * b) * (219 / 255) + 16;
        CBx[i] = (-0.17 * r - 0.33 * g + 0.50 * b) * (224 / 255) + 128;
        CRx[i] = (0.50 * r - 0.42 * g - 0.08 * b) * (224 / 255) + 128;
      }

      // Downsample Cb,Cr (420 format)
      List CB = List<double>(64);
      List CR = List<double>(64);

      for (int i = 0; i < 64; ++i) {
        int j = (i & 7) * 2 + (i & 56) * 4;
        CB[i] = (CBx[j] + CBx[j + 1] + CBx[j + 16] + CBx[j + 17]) * 0.25;
        CR[i] = (CRx[j] + CRx[j + 1] + CRx[j + 16] + CRx[j + 17]) * 0.25;
      }

      // for (int k1=0; k1<2; ++k1) {
      //   for (int k2=0; k2<2; ++k2) {
      //     List block = List<double>(64);
      //     for (int i=0; i<64; i+=8) {
      //       int j = (i&7)+(i&56)*2 + k1*8*16 + k2*8;
      //       // memcpy(block+i, Y+j, 8*sizeof(Y[0]));
      //       block[i] = Y[j]; // was this correctly inferred?
      //     }
      //     print('Block');
      //     print(block);
      //     lastDCY = jo_processDU(bits, block, s_jo_HTDC_Y, lastDCY);
      //   }
      // }
      for (int k1 = 0; k1 < 2; ++k1) {
        for (int k2 = 0; k2 < 2; ++k2) {
          List block = List<double>(64);
          for (int i = 0; i < 64; i += 8) {
            // TODO I changed this back to +=8 from ++
            int j = (i & 7) + (i & 56) * 2 + k1 * 8 * 16 + k2 * 8;

            // memcpy(block+i, Y+j, 8*sizeof(Y[0]));
            for (int k = 0; k < 8; k++) {
              block[i + k] = Y[j + k];
            }
          }
          lastDCY = jo_processDU(bits, block, s_jo_HTDC_Y, lastDCY);
        }
      }
      lastDCCB = jo_processDU(bits, CB, s_jo_HTDC_C, lastDCCB);
      lastDCCR = jo_processDU(bits, CR, s_jo_HTDC_C, lastDCCR);
    }
  }
  // mem.bufferBits(0, 7);
  // mem.put4B(0x00,0x0,0x01,0xb7); // End of Sequence moved to saveVideo
  // size is very small, safe to cast to `int`
}

int bitCount(int v) {
  int p = 0;
  while (v > 0) {
    p++;
    v >>= 1;
  }
  return p;
}

void saveVideo(String path, List images, int width, int height, int fps,
    {repeatFrames: 1}) {
  print('Saving video with ' + images.length.toString() + ' frames');

  var data = BitWriter();
  // encode sequence header
  data.put4B(0x00, 0x00, 0x01, 0xB3);
  // 12 bits for width, height
  data.put1B((width >> 4) & 0xFF);
  data.put1B(((width & 0xF) << 4) | ((height >> 8) & 0xF));
  data.put1B(height & 0xFF);
  // aspect ratio, framerate
  if (fps <= 24) {
    data.put1B(0x12);
  } else if (fps <= 25) {
    data.put1B(0x13);
  } else if (fps <= 30) {
    data.put1B(0x15);
  } else if (fps <= 50) {
    data.put1B(0x16);
  } else {
    data.put1B(0x18); // 60fps
  }
  data.put4B(0xff, 0xff, 0xe0, 0xa0);
  print('Progress:');
  for (int i = 0; i < numFrames; i++) {
    stdout.write(".");
  }
  print('');

  for (Image image in images) {
    stdout.write(".");
    for (int i = 0; i < repeatFrames; i++) {
      encode_mpeg(data, image, width, height, fps);
    }
  }
  print('');
  data.put4B(0x00, 0x0, 0x01, 0xb7);
  // encode sequence end
  // write encoded video out to file
  var fp = File(path);
  var sink = fp.openWrite();

  sink.add(data.getData());
  sink.close();
}

void main() {
  print('MPEG Encoder');
  List<Image> images = [];

  for (var i = 0; i < numFrames; i++) {
    images.add(
        Image.fromFile(imageDirectory + i.toString().padLeft(3, '0') + '.ppm'));
  }
  saveVideo(videoDirectory, images, 512, 512, frameRate);

  // var iter = 0;
  // imageDirectory.list(recursive: false, followLinks: false).listen((
  //   FileSystemEntity entity,
  // ) {
  //   print('Loading frame: ' + entity.path);
  //   try {
  //     images.add(Image.fromFile(entity.path));
  //     jankSortingIndex[entity.path] = iter;
  //     iter++;
  //   } catch (e) {
  //     print(entity.path + " isn't a frame, skipping");
  //   }

  //   if (iter == numFrames) {
  //     //To handle asynchronisity in a definitely jank way
  //     images.sort((a, b) {
  //       return a['name'].toLowerCase().compareTo(b['name'].toLowerCase());
  //     });
  //     saveVideo(videoDirectory, images, 512, 512, 24);
  //     print('Video saved');
  //   }
  // });
}
