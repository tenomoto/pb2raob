#pb2raob
pb2raob reads NCEP PREPBUFR and save rawinsonde observations in a text file.
It is based on an [example program](http://www.nco.ncep.noaa.gov/sib/decoders/BUFRLIB/toc/prepbufr/).

pb2raob extracts rawinsonde observations at mandatory levels
on the hour over land on ship.
Low quality or processed entries are exluded.

## Requirements

pb2raob requires [BUFRLIB](http://www.nco.ncep.noaa.gov/sib/decoders/BUFRLIB/).
pb2raob was written with BUFRLIB 10.2.3.

You may edit Makefile.BUFRLIB to compile BUFRLIB.

## Files

- Makefile: edit FC and the BURLIB name and location
- pb2raob.F: mainsource 
- readpb.prm: parameter file to be included in pb2raob.F at compile time
- Makefile.BUFRLIB: an example Makefile for BUFRLIB

## Usage

The input file name should be prepbufr.in.
Rename the prepbufr file or create a symbolic link.

    $ ./pb2raob

The output is written in readpb.out.ADPUPA.
It contains station ID, longitude (degE), latitude (degN), pressure (hPa), variable name, observed value.
Variables are Q (mg/kg), T (degC), Z (gpm), U (m/s), V (m/s).

## Implementation

- Only ADPUPA is read from PREPBUFR (NFILO = 1, iunso = 52, filo = 'ADPUPA').
- Observations not on the hour (DHR ie hdr(4) /= 0) are ignored.
- Rawinsonde observations (TYP ie hdr(6) == 120 (T, q, z) 220 (u, v)) are selected.
- Fixed land and ship observations (T29 ie hdr(7) == 11 and 22) are retained.
- Low quality data (evns(2, lv, jj, kk) > 2.0) and processed data (evns(4, lv, jj, kk) /= 100) are skipped.
- Mandatory levels (evns(7, lv, 1, 1) == 1.0 or 3.0) are saved.
