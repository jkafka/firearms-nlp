# How to digitize scanned documents into computer-readable text

Many interesting documents are available only as photocopies.  These
cannot be directly searched, analyzed, or processed on a computer with ordinary text
tools.  This repository contains public code, designed to convert such
documents into machine-readable text.  It is designed with the
Washington State court records in mind, but it may be useful for many
other kinds of documents as well, as long as these are typewritten,
not handwritten.

The central part of the the toolkit is an R-script `pdf2txt.R` that
does the actual conversion.  The scanned documents should be of either
PDF or TIF format.  The script uses optical character recognition
(OCR).  Those scanned files are first converted to png images, and
then those images are converted to text.  The final text is stored
both in an R data format (`converted-results.Rdata`) and as a csv
(`converted-results.csv`).


## The script

The script, `pdf2txt.R` can be run either through R console (inside
RStudio), or from command line.  It requires certain packages (see
below),
including _magick_ and _tesseract_ for converting images and doing
OCR.  There are parameters to adjust according to your own
system, take a look at the beginning of the script.

When you start it for the first time, make it verbose
(e.g. `printLevel <- 2`) and run only a small sample of cases
(e.g. `sample <- 10`) to see if everything works well.  Expect the
conversion to take several hours for 1000 cases.

Unfortunately, tesseract outputs many warnings about small
images.  These are harmless.
Typical warnings look like

> Image too small to scale!! (2x36 vs min width of 3)
> Line cannot be recognized!!

Those "image too small" warnings can be ignored.

The script contains a lot of error handling code that makes it a bit
messy, this is largely to be able to catch conversion errors further
down the process (see Section _Troubleshooting_).


## Requirements

The script uses the following packages: _magrittr_, _foreach_,
_pdftools_, _magick_ and _tesseract_.  The latter three are based
on external libraries, in particular _imagemagick_ and _tesseract_.
These will normally be installed together with the corresponding R
packages.

This OCR software only works with upright (portrait) text that is
typed, not handwritten.  You need to ensure the pages are upright.
If they contain handwritten text, expect that to be converted mostly
to gibberish.


## Folder structure

The script needs to know a) where the
original documents are; b) where to store converted images; and c) where
to store converted text.  Both images and text are needed for OCR but
are preserved mostly for troubleshooting purposes.  You may delete
these intermediary folders if all goes well.

The data should be stored as follows (see the figure below):

* **DATADIR** (default "/home/siim/bigdata/firearms-nlp")
  is the project directory.  It refers to the main
  folder, the "root" of all data-related
  folders.  In our default code, it is called
  "/home/siim/bigdata/firearms-nlp", you should adjust it for your
  computer. 
* **CASEDIR** ("court-docs-scanned") refers to the
  folder that contains the scanned court documents.  The actual folder
  name should be modified as needed.  This folder
  will normally reside inside DATADIR, but does not have to.  Inside,
  the files can be split into further subfolders, for instance
  for different counties, years or crime types.  The use
  of subfolders is
  optional, the scanned case document files can reside either directly
  in CASEDIR or in one of its subfolders.  The scanned documents
  can be either
  .pdf or .tif type.
* **PNGDIR** ("converted-pngs") refers to the
  directory for the converted png files--for OCR,
  both pdf and tif images are first converted to png.  The default
  value, "converted-pngs", can be modified but does not have to as the
  script will create this folder as needed.  PNGDIR will
  normally be inside DATADIR, but does not have to be.  The script
  will store the converted page png-s inside this folder.  The pages
  are arranged and named in the same way as the original casefiles,
  just have ending like `-001.png` for the first page, and so on.
  Converted
  png-s are only needed for troubleshooting, so if all is well, you
  can just delete this folder.  Expect png files for 1000 cases to
  take 1GB of disk space.
* **TXTDIR** ("converted-text") refers to the
  directory for the converted text files.  The actual folder name can
  be modified but does not have to--it is also
  automatically created like PNGDIR.   While the
  cleaned text will be put into the final
  data frame and saved to disk, the
  individual converted pages will be saved into TXTDIR, using the same
  arrangement as for the original case files.  These end with
  `-001.txt` for the first page, and so on.
  Unlike the results in the final
  data frame, these
  texts preserve all symbols and line breaks.
  Again, texts are mainly preserved for
  troubleshooting, but can be useful for other of text-based
  tasks too.  Expect the txt files to take 20MB of disk space 
  for 1000 cases.

These folder names should be set in the beginning of the script to
reflect the folder organization on your computer.

An example of how the folder structure looks for one of the actual
project is shown below.

![folder structure](folder-structure.png)

An example file, _16-1-00010-1.pdf_, is shown in red.



## Running the script

The script is basically just a loop over all the pdf/tif files in the
CASEDIR folder.  Files are first loaded, stored as png into PNGDIR,
and then converted to text and stored in TXTDIR.  This results in
separate image and text file for each page.

The script has a few tuning parameters:

* `printLevel`: work verbosity.  The larger number prints more, "2"
  (default), prints each case file name as it goes.
* `outFName.Rdata`: name of the output file in R data fromat--the
  data frame where the
  extracted text is stored.  Default is "converted-results.Rdata".  You
  can as well use the default name and rename it afterward.
* `outFName.csv`: the csv version of the output (default
  "converted-results.csv").
* `sample`: how big a sample to process.  "0" mean to convert all
  files, "10" means to convert only 10 cases, selected by
  random.  Useful for testing/troubleshooting.


## Outcome

By default, the results are saved in
`converted-results.Rdata` (in R format) and `converted-results.csv`
(comma-separated).  These files contain identical results.  The .Rdata
version includes results as a data frame
called _results_ with columns

* **subfolder**: subfolder inside CASEDIR.  In the example on the
  figure above, this
  will be "Clark/2016"
* **filename**: the name of the original file.  In the example above,
  it will be "16-1-00010-1.pdf".
* **pages**: the page count of the original file
* **text**: the case text.  All pages are collapsed into a single
  string, line breaks are replaced with a space.

TBD: single subfolder?  separately first/last subfolder?



## Troubleshooting

Imagemagick may cause trouble as its default
configuration is rather restricted.  For instance, it may set low
memory and pixel size limits and not allow to write pdf documents.
The script tries to address
that by doing certain operations page-by-page, instead of reading all
document as a whole.  But you may still run into errors like 

> Cannot read image ...
> <Magick::ErrorCache in eval(xpr, envir = envir): R: cache resources exhausted

This probably boils down to low memory, pixel size, or file size
limits in the policy file.  The best solution is to change the
policies to be appropriate for this task.  The file is located at
`/etc/ImageMagick-6/policy.xml` on linux.  Unfortunately, both the
toolset and the documentation are geared toward experienced system
administration and not for casual users.  Read the the
[Security Policy Doc](https://imagemagick.org/script/security-policy.php) 
to get a
taste. 

I made the following changes in the `policy.xml` file, not sure
what is actually required:
```
  <policy domain="resource" name="memory" value="4GiB"/>
  <policy domain="resource" name="map" value="4GiB"/>
  <policy domain="resource" name="width" value="16KP"/>
  <policy domain="resource" name="height" value="16KP"/>
  <policy domain="resource" name="area" value="128MP"/>
  <policy domain="resource" name="disk" value="16GiB"/>
  <policy domain="coder" rights="read | write" pattern="PDF" />
```
(There are many more options that I haven't changed).


## Authors

Kaidi Chen (陈凯迪), Ott (奥特) Toomet 

[CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)
