#include <iostream>
#include <fstream>
#include <string>
#include <stdio.h>

#include <math.h> // cos, sin

// for white noise generation (should look into lsfr as a generator for synthesis)
#include <boost/random.hpp>
#include <boost/random/mersenne_twister.hpp>
#include <boost/random/variate_generator.hpp>
#include <boost/random/normal_distribution.hpp>

#include "os_pfb.h"

int main() {

  std::string fname = "data/data.dat";
  std::ofstream fp;
  fp.open(fname, std::ios::binary);

  float fs = 10e3;   // sample rate (Hz)
  float f_soi = 2e3; // SOI sample rate (Hz)
  float t = 2;       // simulation time length (seconds)
  float T = 1/fs;    // sample period (seconds)

  int Nsamps = fs*t;
  int windows = Nsamps/D; // cast as float? because the int division gives the right num...
  char nbytes = sizeof(cx_datain_t);

  // shift amount between filter and ifft
  static int shift_states[SHIFT_STATES];
  for (int i=0; i < SHIFT_STATES; ++i) {
    shift_states[i] = (i*D) % M;
  }

  std::cout << "\n\n";
  std::cout << "Oversampled Polyphase Filterbank Simulation Info\n";
  std::cout << "\t Polyphase branches (M)      : " << M << "\n";
  std::cout << "\t Decimation rate (D)         : " << D << "\n";
  std::cout << "\t Protoype Filter taps (L)    : " << L << "\n";
  std::cout << "\t Polyphase filter taps (L/M) : " << P << "\n";
  std::cout << "\t Frequency shift compensation: [ ";
  for (int i=0; i < SHIFT_STATES; ++i) std::cout << shift_states[i] << " ";
  std::cout << "]\n";

  std::cout << "\nSignal simulation info\n";
  std::cout << "\t Fs (Hz)            : " << fs << "\n";
  std::cout << "\t F_soi (Hz)         : " << f_soi << "\n";
  std::cout << "\t simulation time (s): " << t << "\n";
  std::cout << "\t Number samples     : " << Nsamps << "\n";
  std::cout << "\t processing windows : " << windows << "\n";

  // write simulation info to file
  //fp << t << "," << fs << std::endl; 
  fp.write(&nbytes, sizeof(char));
  fp.write((char*) &t, sizeof(float));
  fp.write((char*) &fs, sizeof(float));

  // initialize noise generator
  boost::mt19937 engine = boost::mt19937(time(0));
  boost::normal_distribution<double> dist = boost::normal_distribution<double>(0,1);
  boost::variate_generator<boost::mt19937, boost::normal_distribution<double>> gen = 
        boost::variate_generator<boost::mt19937, boost::normal_distribution<double>>(engine, dist);

  // data generation and pointers. Complex exponential and white noise
  cx_datain_t data[Nsamps];

  #define SCALE_FACTOR 127 // to keep values between -127 and 128
  float omega = 2*M_PI*f_soi/fs;
  // Note that for the non-streaming formulation the new iterator n represents is the sample
  // index (time series) and is a separate iterator variable from 'i'because time still has
  // to start at 0 even though filling the array backwards
  for (int i=Nsamps-1, n=0; i >= 0; --i, ++n) {
    data[i].real( SCALE_FACTOR*0.1*cos(omega*n) + SCALE_FACTOR*0.1*gen() );
    data[i].imag( SCALE_FACTOR*0.1*sin(omega*n) + SCALE_FACTOR*0.1*gen() );
    //fp << data_re[i] << data_im[i];
    // inefficient to write each loop iter, but not worried about that now
    fp.write((char*) &data[i], sizeof(cx_datain_t));
  }
  fp.close(); // close data file

  // initialize input/output pointers and counters
  int window_ctr = 0;
  cx_dataout_t pfb_output[M][windows];

  cx_datain_t *dataStart = data;
  cx_datain_t *dataEnd = data + Nsamps;
  cx_datain_t *pfb_input = dataEnd - D;

  bool overflow;

  // begin filtering
  // Note that for the non-streaming formulation (advancing the data pointer instead of decrementing)
  // the comparison had to make sure that we still had data to process... but to get the window sizes
  // to match in the streaming case we don't. Need to convince myself more.
  while (pfb_input > dataStart) {
//    cx_dataout_t output[M];
    os_pfb_axis_t output[M];

    // filter
//    os_pfb(pfb_input, output, shift_states, &overflow);
    os_pfb(pfb_input, output, &overflow);

    // copy output
    for (int i=0; i < M; ++i) {
      pfb_output[i][window_ctr] = output[i].data;
    }

    // advance input ptrs and window ctr
    pfb_input -= D;
    window_ctr += 1;

  }
  std::cout << "\nFinished processing! (windows=" << window_ctr << ")\n\n";

  // open a file to writeout results for processing
  fname = "data/out.dat";
  fp.open(fname, std::ios::binary);


  for (int w=0; w < windows; ++w) {
    for (int m=0; m < M; ++m) {
      fp.write((char*) &pfb_output[m][w], sizeof(cx_dataout_t));
    }
  }
  fp.close(); // close out.dat

  return 0;
}
