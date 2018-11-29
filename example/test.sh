set -vex
dos2unix *
perl ../plot.genome.featureCluster.pl --list list5 --prefix out --outdir . --conf main.conf

# remove the crosslinks and decrease the height of figure, change feature type to rect
perl ../plot.genome.featureCluster.pl --list list5 --prefix out2 --outdir . --conf main.2.conf

perl ../plot.genome.featureCluster.pl --list list5 --prefix out3 --outdir . --conf main.3.conf
#perl ../plot.genome.featureCluster.pl --list list5.fake --prefix out.fake --outdir . --conf main.fake.conf # not support yet
perl ../plot.genome.featureCluster.pl --list list6 --prefix out6 --outdir . --conf main.6.conf
perl ../plot.genome.featureCluster.pl --list list7 --prefix out7 --outdir . --conf main.conf
perl ../plot.genome.featureCluster.pl --list list5 --prefix out8 --outdir . --conf main.8.conf
perl ../plot.genome.featureCluster.pl --list list5 --prefix out3.1 --outdir . --conf main.3.1.conf
perl ../plot.genome.featureCluster.pl --list list5 --prefix out3.2 --outdir . --conf main.3.2.conf
perl ../plot.genome.featureCluster.pl --list list5 --prefix out9 --outdir . --conf main.9.conf
#cairosvg  out.svg.in.svg.svg -o out.svg.in.svg.pdf
perl ../prepare.data.pl --list list5 --prefix out9 --outdir . --conf main.10.conf
perl ../plot.genome.featureCluster.pl --list list5.ytick --prefix out10 --outdir . --conf main.10.conf.new
