#!/bin/sh

cd collage_uboot

f=`ls p0*`

cd -
for file in $f; do
	echo "patch -p1<collage_uboot/$file"
	patch -p1<collage_uboot/$file
done



