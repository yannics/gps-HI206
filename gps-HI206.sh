#!/bin/bash
# -------------+
# gps-HI206.sh |
# -------------+
# copyleft 2025/2026 Yann ics All wrongs reserved

# init value ++++++++++++++++
# check id device: $ ls /dev/tty.*
gps=/dev/tty.usbserial-1420

# delta t in second to relate loch
# optional 15 seconds by default
if [[ -z $1 ]]
then
    tps=15
else
    tps=$1
fi
# +++++++++++++++++++++++++++

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# init process ++++++++++++++
gpsd $gps -p
gpspipe -w -o $DIR/gps.json &

    for ((i = 1 ; i <  $tps ; i++ ))
    do
	sleep 1
	echo -n "."
    done

# required $lat1 & lon1 & $tps1
gpsinitpt() {
    if [[ -z $tps1 ]] || [[ -z $lat1 ]] || [[ -z $lon1 ]]
    then 
	tps1=`grep -m 1 "TPV" $DIR/gps.json | jq '.time' | sed 's/\"//;s/T/\ /;s/\..*//'`
	lat1=`grep -m 1 "TPV" $DIR/gps.json | jq '.lat'`
	lon1=`grep -m 1 "TPV" $DIR/gps.json | jq '.lon'`
    else
	return
    fi
    sleep 1
    echo -n "."
    gpsinitpt
}

gpsinitpt

mainfunc() {
    
    tps2=`awk '/TPV/{last=$0} END{print last}' $DIR/gps.json | jq '.time' | sed 's/\"//;s/T/\ /;s/\..*//'`
    lat2=`awk '/TPV/{last=$0} END{print last}' $DIR/gps.json | jq '.lat'`
    lon2=`awk '/TPV/{last=$0} END{print last}' $DIR/gps.json | jq '.lon'`
    
    t1=`date -j -f "%Y-%m-%d %H:%M:%S" "$tps1" +%s`
    t2=`date -j -f "%Y-%m-%d %H:%M:%S" "$tps2" +%s`
    dur=`echo $t2-$t1 | bc`
    
    # clear json file
    > $DIR/gps.json
    
    # compute the distance between 2 gps points
    # sources : https://rosettacode.org/wiki/Haversine_formula#C++
    echo "#define _USE_MATH_DEFINES

    #include <math.h>
    #include <iostream>

    const static double EarthRadiusKm = 6372.8;

    inline double DegreeToRadian(double angle)
    {
         return M_PI * angle / 180.0;
    }

    class Coordinate
    {
    public:
	Coordinate(double latitude, double longitude):myLatitude(latitude), myLongitude(longitude)
	{}

	double Latitude() const
	{
	     return myLatitude;
	}

	double Longitude() const
	{
	     return myLongitude;
	}

	private:

	     double myLatitude;
	     double myLongitude;
    };

    double HaversineDistance(const Coordinate& p1, const Coordinate& p2)
    {
	double latRad1 = DegreeToRadian(p1.Latitude());
	double latRad2 = DegreeToRadian(p2.Latitude());
	double lonRad1 = DegreeToRadian(p1.Longitude());
	double lonRad2 = DegreeToRadian(p2.Longitude());

	double diffLa = latRad2 - latRad1;
	double doffLo = lonRad2 - lonRad1;

	double computation = asin(sqrt(sin(diffLa / 2) * sin(diffLa / 2) + cos(latRad1) * cos(latRad2) * sin(doffLo / 2) * sin(doffLo / 2)));
	return 2 * EarthRadiusKm * computation;
    }

    int main()
    {   
       	Coordinate c1("$lat1","$lon1");
	Coordinate c2("$lat2","$lon2");
	std::cout << HaversineDistance(c1, c2) * 1000.0 << std::endl;
	return 0;
     }" > $DIR/.tmp.cpp
    
     g++ -o $DIR/.haversine $DIR/.tmp.cpp
     dist=`$DIR/.haversine`
     
     rm $DIR/.tmp.cpp
     rm $DIR/.haversine
     
     # avoid division by zero
     if [ $dur -eq 0 ]
     then speedkn=0
     else
	 speedms=$(echo "scale=3; $dist / $dur" | bc)
	 speedkn=$(echo "scale=3; $speedms * 1.94384" | bc | awk '{printf "%f", $0}')
     fi

     #echo ""
     #echo lat:$lat2 long:$lon2
     #echo $speedkn kn 

     res="osascript -e 'display notification \"lat: $lat2\nlong: $lon2\nspeed: $speedkn kn\" with title \"gps-HI206\"'"

     eval "$res"
     
     lat1=$lat2
     lon1=$lon2
     tps1=$tps2
     
     sleep $tps
}

echo "\nTo exit process press CTRL+C"
echo "Then run the following commands:"
echo "$ rm $DIR/gps.json; killall -9 gpsd"

while :
do
    mainfunc
done
