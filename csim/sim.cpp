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

typedef signed char data_t;

int main() {

  const std::string fname = "data/data.dat";
  std::ofstream fp;
  fp.open(fname, std::ios::binary);


  unsigned int M = 32;  // polyphase branches (NFFT)
  unsigned int D = 32;  // Decimation rate (D <= M)
  unsigned int L = 256; // Taps in prototype FIR filter
  unsigned int P = L/M; // Taps in branch of polyphase FIR filter

  float fs = 10e3;   // sample rate (Hz)
  float f_soi = 4e3; // SOI sample rate (Hz)
  float t = 2;       // simulation time length (seconds)
  float T = 1/fs;    // sample period (seconds)

  int Nsamps = fs*t;

  char nbytes = sizeof(data_t);

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
  data_t data_re[Nsamps];
  data_t data_im[Nsamps];

  data_t *data_ptr_re = data_re;
  data_t *data_ptr_im = data_im;

  data_t *dataEnd_re = data_re + Nsamps;
  data_t *dataEnd_im = data_im + Nsamps;

  #define SCALE_FACTOR 127 // to keep values between -127 and 128
  float omega = 2*M_PI*f_soi/fs;
  for (int i=0; i < Nsamps; i++) {
    data_re[i] = SCALE_FACTOR*0.1*cos(omega*i) + SCALE_FACTOR*0.1*gen();
    data_im[i] = SCALE_FACTOR*0.1*sin(omega*i) + SCALE_FACTOR*0.1*gen();
    //fp << data_re[i] << data_im[i];
    fp.write((char*) &data_re[i], sizeof(data_t)); // inefficient to write each loop iter, but not worried about that now
    fp.write((char*) &data_im[i], sizeof(data_t));
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
  return 0;
}
