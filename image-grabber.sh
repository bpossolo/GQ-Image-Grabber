#!/bin/bash

#############################################
# Purpose: This script downloads runway
#   pictures from the GQ website.
#
# Author: sq4you/incognito
#
# Date: Sep 25 2011
#############################################

rm -rf tmp
mkdir tmp
test ! -d images && mkdir images

declare -a designerKeys
declare -a seasons

#############################################
# determine which usage form was invoked
#############################################

if [ $# -eq 0 ]; then

	echo "How to use this script:"
	echo ""
	echo "$0"
	echo "$0 DESIGNER [DESIGNER...]"
	echo "$0 -d DESIGNER -s SEASON"
	echo "$0 -d DESIGNER --list-seasons"
	echo "$0 --list-designers"
	echo "$0 --all"
	echo ""
	echo "    In the first form, the script prints this help message."
	echo "    In the second form, the script downloads all images for the specified designer keys."
	echo "    In the third form, the script downloads images of the given season for the specified designer key."
	echo "    In the fourth form, the script prints the list of seasons available for the specified designer key."
	echo "    In the fifth form, the script prints the list of designer keys."
	echo "    In the sixth form, the script downloads all images of all designers."
	exit 0

elif [ $1 == "--all" ]; then

	designerKeys=`curl -s http://www.gq.com/fashion-shows/ | sed -n -f regex/designer-key-regex`
	
elif [ $1 == "--list-designers" ]; then
	
	echo "---List of designer keys---"
	curl -s http://www.gq.com/fashion-shows/ | sed -n -f regex/designer-map-regex
	exit 0

elif [ $# -eq 3 -a "$1" == "-d" -a "$3" == "--list-seasons" ]; then

	echo "---List of seasons for designer key $2---"
	seasons=`curl -s http://www.gq.com/fashion-shows/brief/F2011MEN-$2 | sed -n -f regex/season-regex`
	if [ -z "$seasons" ]; then
		seasons=`curl -s http://www.gq.com/fashion-shows/brief/S2010MEN-$2 | sed -n -f regex/season-regex`
	fi
	for season in $seasons; do
		echo $season
	done
	exit 0

elif [ $# -eq 4 -a "$1" == "-d" -a "$3" == "-s" ]; then

	designerKeys=$2
	seasons=$4

else
	designerKeys=$@
fi

#############################################
# download the images
#############################################

for designerKey in $designerKeys ; do

	echo "Processing designer [$designerKey]"
	
	#check fall and summer URLs for season list since some designers do not have a fall collection
	if [ -z "$seasons" ]; then
		seasons=`curl -s http://www.gq.com/fashion-shows/brief/F2011MEN-$designerKey | sed -n -f regex/season-regex`
	fi
	if [ -z "$seasons" ]; then
		seasons=`curl -s http://www.gq.com/fashion-shows/brief/S2010MEN-$designerKey | sed -n -f regex/season-regex`
	fi
	
	for season in $seasons ; do
	
		echo "  Processing season [$season]"

		xmlFile=tmp/$season-$designerKey.xml
		curl -s -o $xmlFile http://www.gq.com/api/data-streamer?id=empty\&out=xml\&dsType=slideshow\&season=$season\&designCode=$designerKey
		
		imageCount=`xpath $xmlFile "count(//slideshow/slides-set/slide/photos/photo[@type='FULL_SCREEN_IMAGE'])" 2> /dev/null`

		if [ $imageCount -ne 0 ]; then
			echo "    Found $imageCount large images to download"
			imageUrls=`xpath $xmlFile "//slideshow/slides-set/slide/photos/photo[@type='FULL_SCREEN_IMAGE']/@uri" 2> /dev/null`
		else
			imageCount=`xpath $xmlFile "count(//slideshow/slides-set/slide/photos/photo[@type='IMAGE_320X480'])" 2> /dev/null`
			echo "    Found $imageCount medium images to download"
			imageUrls=`xpath $xmlFile "//slideshow/slides-set/slide/photos/photo[@type='IMAGE_320X480']/@uri" 2> /dev/null`
		fi
		
		runwayImagesDir=images/$designerKey/$season/runway
		detailsImagesDir=images/$designerKey/$season/details
		runwayCounter=0
		detailCounter=0
		
		test ! -d $runwayImagesDir && mkdir -p $runwayImagesDir
		
		for url in $imageUrls ; do
			
			url=`echo $url | sed -f regex/clean-url-regex`
			
			echo "      Downloading http://www.gq.com${url}"
			
			if echo $url | grep -q "RUNWAY"; then
				curl -s -o $runwayImagesDir/$runwayCounter.jpg http://www.gq.com$url
				((runwayCounter++))
			else
				test ! -d $detailsImagesDir && mkdir $detailsImagesDir
				curl -s -o $detailsImagesDir/$detailCounter.jpg http://www.gq.com$url
				((detailCounter++))
			fi
		done
    done
    
    unset seasons
done

rm -rf tmp

echo "Finished downloading files from GQ!"
