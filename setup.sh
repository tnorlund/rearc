#!/bin bash

# The point of this script is to:
# 1. Download all wheels from PyPi
# 2. Unpack the wheels locally
# 3. Create the folder structure required for the lambda layer
# 4. Upload the requirements to the S3 bucket

if ( test -f "./python.zip" ); then
  rm ./python.zip
fi

# Download all the required wheels
files_from_wheels=()
# echo "downloading requirements"
while read p; do
  curl -O "$p" &> /dev/null;

  # curl -P downloads/ "$p" &> /dev/null;
done < requirements_url.txt

# Install wheel
python -m pip install --upgrade pip &> /dev/null;
python -m pip install wheel &> /dev/null;

# Unpack all of the wheels
for i in *.whl; do
  wheel_file=$(python -m wheel unpack "$i")
  length=${#wheel_file}
  # Remove the first 14 and last 5 characters. The last index is 14+5
  endindex=$(expr $length - 19)
  wheel_file="${wheel_file:14:$endindex}"
  files_from_wheels+=("$wheel_file")
  rm $i;
done

# Make the required folder structure
mkdir python;
mkdir python/lib;
mkdir python/lib/python3.9
mkdir python/lib/python3.9/site-packages

for wheel_directory in "${files_from_wheels[@]}"; do
  # echo "$wheel_directory"
  for files_from_this_wheel in $(ls $wheel_directory); do
    # echo "$wheel_directory/$files_from_this_wheel"
    mv -f "$wheel_directory/$files_from_this_wheel" python/lib/python3.9/site-packages;
  done
  rm -rf $wheel_directory
done

# Clean up the directory and upload the ".zip" to S3
zip -r python.zip ./python &> /dev/null;
rm -rf ./python
aws s3 cp ./python.zip s3://tf-cloud/rearc/
rm python.zip

zip part1.zip part1.py
aws s3 cp ./part1.zip s3://tf-cloud/rearc/
rm part1.zip

zip part2.zip part2.py
aws s3 cp ./part2.zip s3://tf-cloud/rearc/
rm part2.zip

zip part3.zip part3.py
aws s3 cp ./part3.zip s3://tf-cloud/rearc/
rm part3.zip