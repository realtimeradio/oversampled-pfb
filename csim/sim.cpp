#include <iostream>
#include <fstream>
#include <string>
#include <stdio.h>

#include <math.h> // cos, sin

// for white noise generation (should look into lsfr as a generator)
#include <boost/random.hpp>
#include <boost/random/mersenne_twister.hpp>
#include <boost/random/variate_generator.hpp>
#include <boost/random/normal_distribution.hpp>

int main() {

  const std::string fname = "data/data.dat";
  std::ofstream fp;
  fp.open(fname);


  unsigned int M = 32;  // polyphase branches (NFFT)
  unsigned int D = 32;  // Decimation rate (D <= M)
  unsigned int L = 256; // Taps in prototype FIR filter
  unsigned int P = L/M; // Taps in branch of polyphase FIR filter

  float fs = 10e3;   // sample rate (Hz)
  float f_soi = 4e3; // SOI sample rate (Hz)
  int   t = 2;       // simulation time length (seconds)
  float T = 1/fs;    // sample period (seconds)

  int Nsamps = fs*t;

  // write simulation info to file
  fp << t << "," << fs << std::endl;

  // initialize noise generator
  boost::mt19937 engine = boost::mt19937(time(0));
  boost::normal_distribution<double> dist = boost::normal_distribution<double>(0,1);
  boost::variate_generator<boost::mt19937, boost::normal_distribution<double>> gen = 
        boost::variate_generator<boost::mt19937, boost::normal_distribution<double>>(engine, dist);

  // data generation and pointers. Complex exponential and white noise
  float data_re[Nsamps];
  float data_im[Nsamps];

  float *data_ptr_re = data_re;
  float *data_ptr_im = data_im;

  float *dataEnd_re = data_re + Nsamps;
  float *dataEnd_im = data_im + Nsamps;

  float omega = 2*M_PI*f_soi/fs;
  for (int i=0; i < Nsamps; i++) {
    data_re[i] = cos(omega*i) + gen();
    data_im[i] = sin(omega*i) + gen();
    fp << data_re[i] << "," << data_im[i] << std::endl;
  }


  float filter_state_re[L]; // real filter products
  float filter_state_im[L]; // imaginary filter products
  float *state_re = filter_state_re;
  float *state_im = filter_state_im;
  float *stateEnd_re = filter_state_re + L;
  float *stateEnd_im = filter_state_im + L;


  float shift_buffer[L];
  float ifft_buffer[M];

  // begin filtering
//  while (data_ptr < (dataEnd_re-D) {
//
//    // shift the contents of filter state to allow for new data
//    float p* = state_re + D; // pointers starting at D in the filter state
//    float k* = state_im + D;
//    for ( ; p != stateEnd_re; ++p, ++k) {
//
//    }
//
//
//  }



  fp.close();
  std::cout << "Ran without problems...\n";
  return 0;
}
