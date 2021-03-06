set -vex

uname=`uname|grep MINGW|wc -l`
if [ "$uname" -eq 1 ];
then
	find .  -type f -exec grep -Iq . {} \; -and -print|xargs -L 1 -I {} dos2unix {}
fi


perl ../plot.genome.featureCluster.pl --list list5 --prefix out --outdir . --conf main.conf

perl ../plot.genome.featureCluster.pl --list list5 --prefix out2 --outdir . --conf main.2.conf

perl ../plot.genome.featureCluster.pl --list list5 --prefix out3 --outdir . --conf main.3.conf

sh out7.sh

perl ../plot.genome.featureCluster.pl --list list5 --prefix out8 --outdir . --conf main.8.conf
perl ../plot.genome.featureCluster.pl --list list5 --prefix out3.1 --outdir . --conf main.3.1.conf
perl ../plot.genome.featureCluster.pl --list list5 --prefix out3.2 --outdir . --conf main.3.2.conf
perl ../plot.genome.featureCluster.pl --list list5 --prefix out9 --outdir . --conf main.9.conf
#cairosvg  out.svg.in.svg.svg -o out.svg.in.svg.pdf
sh out10.sh
sh out11.sh
echo done
