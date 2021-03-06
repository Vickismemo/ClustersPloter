#!/usr/bin/env perl -w
use strict;
use warnings;
use Getopt::Long;
use FindBin qw($Bin);
use List::Util qw(max min);
use lib "$Bin";
use myth qw(format_scale read_list draw_genes display_conf read_conf default_setting check_track_order check_para get_para shift_tracks);

my ($list,$prefix,$outdir,$conf,$track_reorder);
GetOptions("list:s"=>\$list,
		"prefix:s"=>\$prefix,
		"outdir:s"=>\$outdir,
		"conf:s"=>\$conf
	  );

die "
perl $0 [options]:
* --list <str>  two formats: [sample gff genome seq_id1 seq_draw_start1 seq_draw_end1 genome seq_id2 seq_draw_start2 seq_draw_end2 ...]
or [sample gff genome]no seq_id mean full length of whole gff
* --prefix <str>
* --outdir <str>
* --conf <str> 

writed by myth
" unless($list && $prefix && $outdir && $conf);
if(! -d "$outdir"){
	`mkdir -p $outdir`;
}

my @track_reorder;
my @funcs=();
my %conf = &read_conf($conf,@funcs);
($conf, $track_reorder) = &default_setting(%conf);
%conf=%$conf;
@track_reorder=@$track_reorder;

&check_para(%conf);


my $shift_angle_closed_feature=0;
my ($svg_width,$svg_height) = split(',',$conf{'svg_width_height'});


## position of features for  crosslink
my %positon_links;
my @fetures_links;

##start:get max scaffolds lengths in gff file
my ($ref_name_width_ratio, $cluster_width_ratio, $legend_width_ratio) = split(/-/, $conf{width_ratio_ref_cluster_legend});
if($ref_name_width_ratio+$cluster_width_ratio+$legend_width_ratio !=1){
	die "error:width_ratio_ref_cluster_legend in $list ,the sum is not equal to 1\n";
}


###start:get scaffold length in genome file and scaffold length  in gff file of list 
print "start read $list\n";
my ($genome, $gff, $track_order, $sample_num, $fts, $conf2) = &read_list($list, \%conf);
my %genome=%$genome;
my %gff=%$gff;
my %fts=%$fts;
%conf=%$conf2;
my @track_order=@$track_order;
print "end read $list\n";
#die "track_order is @track_order, track_reorder is @track_reorder\n";
@track_order=&check_track_order(\@track_order, \@track_reorder);



my $ends_extend_ratio = 0.1;
my $max_length;
my $space_len = $conf{space_between_blocks};# 500bp是默认的blocks之间的间距
foreach my $s(sort {$gff{$b}{chooselen_all}<=>$gff{$a}{chooselen_all}} keys %gff){
	$max_length=$gff{$s}{chooselen_all}-$space_len;
	last;
}
my $ratio=$cluster_width_ratio*$svg_width/$max_length;


my $index;
my $common_size;
my $top_bottom_margin=$conf{top_bottom_margin};
my %orders;
my $svg="<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\" width=\"$svg_width\" height=\"$svg_height\" style=\"background-color:$conf{svg_background_color};\">\n";
my $top_distance=$top_bottom_margin/2*$svg_height;
#tracks_shift_y=chr14,0,+1 #sampl
#die "track_order is @track_order\n";
my %tracks_shift_y = &shift_tracks($conf{tracks_shift_y}, \@track_order);


my $sample_single_height = (1 - $top_bottom_margin)*$svg_height/$tracks_shift_y{num}; # 每个track的高度
#die "num is $tracks_shift_y{num}\n";
my $id_line_height = $sample_single_height/100 * $conf{genome_height_ratio}; # 每个block的genome的高度

my $ref_name_right_gap=0.1;
#my $left_distance_init = (1 - 0.1) * $ref_name_width_ratio * $svg_width ;#block左侧起点的x轴,0.1是指ref name和第一个block的间隔
my $left_distance_init = $ref_name_width_ratio * $svg_width ;#block左侧起点的x轴,0.1是指ref name和第一个block的间隔


my ($down_percent_unit,$up_percent_unit,$ytick_region_ratio,$start_once,$end_once);
my $index_id_previous="";
my $display_segment_name=$conf{display_segment_name};
die "error:display_segment_name $display_segment_name format error, should like display_segment_name=yes,center,shift_y:+1,fontsize:10,color:black,order:5\n" if($display_segment_name!~ /^([^,]+),([^,]+),shift_y:([-\+\d\.]+),fontsize:([\d\.]+),color:(\S+),order:(\d+)/);
my $display_segment_name_flag=$1;
my $display_segment_name_pos=$2;
my $display_segment_name_shift_y=$3*$sample_single_height/100;
my $display_segment_name_fontsize=$4;
my $display_segment_name_color=$5;
my $display_segment_name_order=$6;

while(@track_order){
	$index++;
	my $sample = shift @track_order;
#die "num is $tracks_shift_y{num}, $sample_single_height * $tracks_shift_y{$sample}{shift_y}\n";
#$top_distance+=$sample_single_height * ($tracks_shift_y{$sample}{shift_y}-1) if($index == 1);
	$top_distance+=$tracks_shift_y{sample}{$sample}{shift_y_up} * $sample_single_height;
	$up_percent_unit=(($sample_single_height-$id_line_height)/2 -1 + $tracks_shift_y{sample}{$sample}{shift_y_up} * $sample_single_height)/100;
	$down_percent_unit=(($sample_single_height-$id_line_height)/2 -1 + $tracks_shift_y{sample}{$sample}{shift_y_down} * $sample_single_height)/100;

	die "error: sample :$sample: is not in gff file of --list \n" if (not exists $gff{$sample});
	my $block_distance = $space_len*$ratio; # block_distance 是每个block的间距
		my $flag;
	my $left_distance = $left_distance_init ;#block左侧起点的x轴,0.1是指ref name和第一个block的间隔
#my $line_to_sample_single_top_dis=0.45; #track cluster顶部 y 轴在一个track高度的0.45，即cluster的y轴的底部在0.55，即一个cluster高度是整个track的0.55-0.45=0.1
		my $line_to_sample_single_top_dis = 0.5 - $conf{genome_height_ratio}/2/100;#genome_height_ratio
		my $shift_x = $left_distance;

# write sample name for track
	my $text_size = $id_line_height * 1; # sample name 文字大小
		$common_size = $text_size;
	my $ref_name_x = (1- $ref_name_right_gap )* $svg_width * $ref_name_width_ratio; # sample name 右下角end的x和y轴
#my $ref_name_y = $top_distance + (0.5 + 0.05*$conf{genome_height_ratio}) * $sample_single_height; #和block的genome起点的y坐标+block的genome的高度
	my $ref_name_y=$top_distance+0.5*$sample_single_height;

	$conf{sample_name_old2new2}{$sample}{new_name} = $sample if(not exists $conf{sample_name_old2new2}{$sample}{new_name});
	$conf{sample_name_old2new2}{$sample}{new_color} = $conf{sample_name_color_default} if(not exists $conf{sample_name_old2new2}{$sample}{new_color});
	$conf{sample_name_old2new2}{$sample}{new_font_size} = $conf{sample_name_font_size_default} if(not exists $conf{sample_name_old2new2}{$sample}{new_font_size});
	$svg.="<text x=\"$ref_name_x\" y=\"$ref_name_y\" font-size=\"$conf{sample_name_old2new2}{$sample}{new_font_size}px\" fill=\"$conf{sample_name_old2new2}{$sample}{new_color}\"  text-anchor='end' alignment-baseline=\"middle\" >$conf{sample_name_old2new2}{$sample}{new_name}</text>\n"; # draw sample name
	print "draw sample name $conf{sample_name_old2new2}{$sample}{new_name}\n";


	my $pre_block='';
	foreach my $block_index(sort {$a<=>$b} keys %{$gff{$sample}{block}}){ # one block_index ---> one scaffold ---> one cluster of genes
#print "block_index is $block_index, sample is $sample\n";
		$flag++;
		my $shift_angle_closed_feature=0;
#print "block_index is $block_index, sample is $sample\n";
		my @scf = keys %{$gff{$sample}{block}{$block_index}};
#print "scff is @scf, $block_index\n";
		die "error:block_index $block_index should not have two scf\n" if(@scf!=1);
		my $id_line_x=$left_distance; # 每个block的genome的起点的x,y坐标
			my $id_line_y=$top_distance + $line_to_sample_single_top_dis * $sample_single_height; # 每个block的genome的起点的x,y坐标
			my $id_line_width=$gff{$sample}{chooselen_single}{$block_index}{len} * $ratio; # 每个block的genome的宽度
#print "chooselen_single is $sample $gff{$sample}{chooselen_single}{$block_index} * $ratio\n";

### draw main scaffold line track
#$svg.="<rect x=\"$id_line_x\" y=\"$id_line_y\" width=\"$id_line_width\" height=\"$id_line_height\" style=\"fill:$conf{track_style}\"   />\n";
			my $track_order=$conf{track_order};
		foreach my $f(keys %{$conf{feature_setting2}}){
			next if ( (not exists $conf{feature_setting2}{$f}{track_order}) || $conf{feature_setting2}{$f}{scf_id} ne $scf[0] || $conf{feature_setting2}{$f}{sample} ne $sample);
#print "$conf{feature_setting}{$f}{scf_id} ne $scf[0] || $conf{feature_setting}{$f}{sample} ne $sample\n";
#print "f is $f\n\n";
			my $start_f=$conf{feature_setting2}{$f}{start};
			my $end_f=$conf{feature_setting2}{$f}{end};
			if($start_f >= $gff{$sample}{chooselen_single}{$block_index}{start} && $end_f<=$gff{$sample}{chooselen_single}{$block_index}{end}){
				$track_order=$conf{feature_setting2}{$f}{track_order};
#print "$conf{feature_setting}{$f}{track_order}, $conf{feature_setting}{$f}{scf_id} ne $scf[0] || $conf{feature_setting}{$f}{sample} ne $sample;track_order is $track_order;sample is $sample, scf is @scf\n\n\n";
			}
		}
		$start_once=$gff{$sample}{chooselen_single}{$block_index}{start};
		$end_once=$gff{$sample}{chooselen_single}{$block_index}{end};
		$orders{$track_order}.="<g><title>$scf[0]:$gff{$sample}{chooselen_single}{$block_index}{start}-$gff{$sample}{chooselen_single}{$block_index}{end}</title>\n<rect x=\"$id_line_x\" y=\"$id_line_y\" width=\"$id_line_width\" height=\"$id_line_height\" style=\"$conf{track_style}\"   /></g>\n";
		#$conf{display_segment_name} ||="yes,center,shift_y:+1,fontsize:10,color:black"
		#	
		#my $display_segment_name_flag=$1;
		#my $display_segment_name_pos=$2;
		#my $display_segment_name_shift_y=$3*$sample_single_height/100;
		#my $display_segment_name_fontsize=$4;
		#my $display_segment_name_color=$5;
		if($display_segment_name_flag=~ /yes/i){
			my $segment_baseline;
			my $segment_text_anchor;
			my $segment_name_x;
			if($display_segment_name_pos eq "left"){
				$segment_text_anchor="start";
				$segment_name_x=$id_line_x;
			}elsif($display_segment_name_pos eq "right"){
				$segment_text_anchor="end";
				$segment_name_x=$id_line_x+$id_line_width-1;
			}elsif($display_segment_name_pos eq "center"){	
				$segment_text_anchor="middle";
				$segment_name_x=$id_line_x+0.5*$id_line_width-1;
			}else{
				die "error:display_segment_name_pos not support $display_segment_name_pos, only support left right center\n";
			}

			my $segment_name_y=$id_line_y+0.5*$id_line_height;
			if($display_segment_name_shift_y=~ /^[\+-]0$/){
				$segment_baseline="middle";
			}elsif($display_segment_name_shift_y=~ /^[\d\+\.]+$/){
				$segment_baseline="hanging";
				$segment_name_y+=$display_segment_name_shift_y;
			}elsif($display_segment_name_shift_y=~ /^-([\d\.])+$/){	
				$segment_baseline="baseline";
				$segment_name_y+=$display_segment_name_shift_y;
			}else{
				die "error:display_segment_name_shift_y not support $display_segment_name_shift_y in $display_segment_name, should like +1 or -1 or 0\n";
			}
			my $segment_name=($gff{$sample}{chooselen_single}{$block_index}{len} == $gff{$sample}{scf}{$scf[0]})? "$scf[0]":"$scf[0]:$start_once-$end_once";
			$orders{$display_segment_name_order}.="<text x=\"$segment_name_x\" y=\"$segment_name_y\" font-size=\"${display_segment_name_fontsize}px\" fill=\"$display_segment_name_color\"  text-anchor='$segment_text_anchor' alignment-baseline=\"$segment_baseline\" >$segment_name</text>\n"; # draw sample name
		}elsif($display_segment_name_flag!~ /no/i){
			die "error:$display_segment_name should be start with yes or no, not $display_segment_name_flag\n"
		}
## 判断相邻的block是否来自同一条scaffold
		if($scf[0] eq $pre_block and $conf{connect_with_same_scaffold}=~ /yes/i){
			my $pre_x = $id_line_x - $block_distance;
			my $pre_y = $id_line_y + 0.5 * $id_line_height;
			my $now_x = $pre_x + $block_distance * 0.99;
			my $now_y = $pre_y;
#print "pre_block $pre_block $pre_x $pre_y $now_x $now_y\n";
			my $stroke_dasharray=$conf{connect_stroke_dasharray};
			my $stroke_width=$conf{connect_stroke_width};
			my $stroke_color=$conf{connect_stroke_color};
			$svg.="<g fill=\"none\" stroke=\"$stroke_color\" stroke-width=\"$stroke_width\"><path stroke-dasharray=\"$stroke_dasharray\" d=\"M$pre_x,$pre_y L$now_x,$now_y\" /></g>";
		}
#$gff{$sample}{chooselen_single}{$block_index}{end_x_in_svg} = $shift_x+$id_line_width;
		$gff{$sample}{chooselen_single}{$block_index}{end_x_in_svg} = $id_line_x+$id_line_width;
		$gff{$sample}{chooselen_single}{$block_index}{end_y_in_svg} = $id_line_y;

		$left_distance+=($block_distance+$id_line_width); #每个block左侧起点的x坐标shift
			$pre_block = $scf[0];


### draw genes
#print "here\n";
#print "scf is @scf,$sample,$block_index\n";
		my $angle_flag=0;
		my $pre_index_end=0;
		my $pre_scf_id="";


		my @index_id_arr=(sort {$gff{$sample}{block}{$block_index}{$scf[0]}{$a}{start}<=>$gff{$sample}{block}{$block_index}{$scf[0]}{$b}{start}} keys %{$gff{$sample}{block}{$block_index}{$scf[0]}});
		foreach my $index(sort {$gff{$sample}{block}{$block_index}{$scf[0]}{$a}{start}<=>$gff{$sample}{block}{$block_index}{$scf[0]}{$b}{start}} keys %{$gff{$sample}{block}{$block_index}{$scf[0]}}){
#next if($index eq "len");
#print "here $sample $block_index $scf[0] $index\n";
			shift @index_id_arr;
			my $gene_height_medium;
			my $index_id = $gff{$sample}{block}{$block_index}{$scf[0]}{$index}{id};
#print "index_id is $index_id, sample is $sample\n";
#$gff{$sample}{block}{$block}{$scf}{$gene}{id}
#print "\nindex id is $index_id\n";
			die "die:index_id is $index_id,$sample $block_index $scf[0] $index\n" if(not $index_id);
			my $index_start = $gff{$sample}{block}{$block_index}{$scf[0]}{$index}{start};
			my $index_end = $gff{$sample}{block}{$block_index}{$scf[0]}{$index}{end};
			my $index_strand = $gff{$sample}{block}{$block_index}{$scf[0]}{$index}{strand};
			my $index_start_raw = $gff{$sample}{block}{$block_index}{$scf[0]}{$index}{start_raw};
			my $index_end_raw = $gff{$sample}{block}{$block_index}{$scf[0]}{$index}{end_raw};

			my $index_color = &get_para("feature_color", $index_id, \%conf);
			my $display_feature_label = &get_para("display_feature_label", $index_id, \%conf);
			my $feature_not_mark_label = ($display_feature_label=~ /^yes$/i or $display_feature_label=~ /,yes/i)? $index_id:"";

			my $index_label_content = (exists $conf{feature_setting2}{$index_id}{feature_label})? (($display_feature_label=~ /^yes$/ or $display_feature_label=~ /^yes,/)? $conf{feature_setting2}{$index_id}{feature_label}:""):$feature_not_mark_label;
			my $index_label_size = &get_para("feature_label_size", $index_id, \%conf);
			my $index_label_col = &get_para("feature_label_color", $index_id, \%conf);
			my $index_label_position = &get_para("pos_feature_label", $index_id, \%conf);
			my $index_label_angle = &get_para("label_rotate_angle", $index_id, \%conf);

			my $feature_height_ratio = &get_para("feature_height_ratio", $index_id, \%conf);
			my $feature_height_unit = &get_para("feature_height_unit", $index_id, \%conf);

			my $feature_shift_y = &get_para("feature_shift_y", $index_id, \%conf);
			if($feature_height_unit=~ /percent/){
				if($feature_shift_y=~ /^\d/||$feature_shift_y=~ /^\+\d/){
					$gene_height_medium=$down_percent_unit*$feature_height_ratio;
				}else{
					$gene_height_medium=$up_percent_unit*$feature_height_ratio;
				}
			}elsif($feature_height_unit=~ /backbone/){
				$gene_height_medium = $id_line_height * $feature_height_ratio;
			}else{
				die "error:feature_height_unit only support percent or backbone, but $feature_height_unit for $index_id\n"
			}

#print "index_label_angle is $index_label_angle\n";
			my $gene_height_top = &get_para("feature_arrow_sharp_extent", $index_id, \%conf);
			my $feature_shape=&get_para("feature_shape", $index_id, \%conf);
			my $ignore_sharp_arrow=&get_para("ignore_sharp_arrow", $index_id, \%conf);
			$gene_height_top=($feature_shape=~ /arrow/)? $id_line_height*$gene_height_top:0;
			my $sharp_len=($ignore_sharp_arrow=~ /yes/)? 0:$gene_height_top;
			my $feature_label_auto_angle_flag=&get_para("feature_label_auto_angle_flag", $index_id, \%conf);
			$conf{feature_setting2}{$index_id}{cross_link_shift_y}=0.5*$gene_height_medium + $sharp_len;

			my $gene_width_arrow = &get_para("feature_arrow_width_extent", $index_id, \%conf);
			$angle_flag=0;
			if($feature_label_auto_angle_flag){
				my $feature_shift_y_previous = ($index_id_previous)? &get_para("feature_shift_y",$index_id_previous, \%conf):$feature_shift_y;
				if($scf[0] eq $pre_scf_id && ($index_start - $pre_index_end) <= $conf{distance_closed_feature} && ($index_end - $index_start)< 3*$conf{distance_closed_feature} && abs($feature_shift_y_previous-$feature_shift_y) <= 0.5){
					$angle_flag = 1
				}else{
					$angle_flag = 0
				}
			}
			#my $index_id_next=(@index_id_arr>=1)? "$index_id_arr[0]":"";



#print "angle is $angle_flag\n";
## draw_gene 函数需要重写，输入起点的xy坐标，正负链等信息即可
			my $svg_gene; 
#for my $scf(keys %{$gff{$sample}{block}{$block_index}}){				
#				for my $gene(keys %{$gff{$sample}{block}{$block_index}{$scf}}){
#					print "isis4 $sample $block_index $scf $gene, $gff{$sample}{block}{$block_index}{$scf}{$gene}{id}\n";
#				}
#			}
#print "index_id is $index_id\n";
			my $orders;
			($svg_gene, $shift_angle_closed_feature, $orders)=&draw_genes(
					$index_id,
					$index_start, 
					$index_end, 
					$index_strand,
					$index_start_raw, 
					$index_end_raw, 
					$gene_height_medium,
					$gene_height_top,
					$gene_width_arrow,
					$shift_x,
					$top_distance,
					$feature_shift_y,
					$sample_single_height,
					$sample,
					$scf[0],
					$index_color,
					$index_label_content,
					$index_label_size,
					$index_label_col,
					$index_label_position,
					$index_label_angle,
					$angle_flag, \%conf, $ratio, $id_line_height, $shift_angle_closed_feature, \%orders, $up_percent_unit, $down_percent_unit); 		## draw_gene 函数需要重写，输入起点的xy坐标，正负链等信息即可
						$svg.=$svg_gene;
			%orders=%$orders;
			$pre_index_end = $index_end;
			$pre_scf_id = $scf[0];
			$index_id_previous=$index_id;

		}
		$shift_x+=($id_line_width+$block_distance);
	}
	$top_distance+=$sample_single_height * (1+$tracks_shift_y{sample}{$sample}{shift_y_down});
#$gff{$sample}{id}{$arr[0]}{$gene_index}{end}=$arr[4]



}

print "\n\n";
#for my $id(keys %{$conf{crossing_link2}{position}}){
#	print "1id is $id\n"
#}

print "\n\n";


# draw crossing_links for feature crosslink
foreach my $pair(keys %{$conf{crossing_link2}{index}}){
#$conf{crossing_link2}{index}{"$arr[0],$arr[1]"}{$arr[2]} = $arr[3];
	my ($up_id, $down_id) = split(",", $pair);
#print "2id is $up_id\n";
	my $color=(exists $conf{crossing_link2}{index}{$pair}{cross_link_color})? $conf{crossing_link2}{index}{$pair}{cross_link_color}:$conf{cross_link_color};
	my $cross_link_orientation=(exists $conf{crossing_link2}{index}{$pair}{cross_link_orientation})? $conf{crossing_link2}{index}{$pair}{cross_link_orientation}:$conf{cross_link_orientation};
	my $cross_link_opacity=(exists $conf{crossing_link2}{index}{$pair}{cross_link_opacity})? $conf{crossing_link2}{index}{$pair}{cross_link_opacity}:$conf{cross_link_opacity};
	my $cross_link_order=(exists $conf{crossing_link2}{index}{$pair}{cross_link_order})? $conf{crossing_link2}{index}{$pair}{cross_link_order}:$conf{cross_link_order};
	my $cross_link_anchor_pos=(exists $conf{crossing_link2}{index}{$pair}{cross_link_anchor_pos})? $conf{crossing_link2}{index}{$pair}{cross_link_anchor_pos}:$conf{cross_link_anchor_pos};
	my $cross_link_width_ellipse=(exists $conf{crossing_link2}{index}{$pair}{cross_link_width_ellipse})? $conf{crossing_link2}{index}{$pair}{cross_link_width_ellipse}:$conf{cross_link_width_ellipse};
	my $crosslink_stroke_style=(exists $conf{crossing_link2}{index}{$pair}{crosslink_stroke_style})? $conf{crossing_link2}{index}{$pair}{crosslink_stroke_style}:$conf{crosslink_stroke_style};
	die "error: cross_link_width_ellipse $cross_link_width_ellipse should be number\n" if($cross_link_width_ellipse!~ /^[\d\.]+$/);
	die "error1: $up_id of crosslink is not in --list regions, please try to check it, conf{crossing_link2}{position}{$up_id}{start}{x}\n" if(not exists $conf{crossing_link2}{position}{$up_id}{start}{x});
	die "error:crosslink_stroke_style=$crosslink_stroke_style format error, should be like crosslink_stroke_style=stroke:green;stroke-width:1\n" if($crosslink_stroke_style!~ /^stroke:[^;]+;stroke-width:[\d\.]+;$/);
	my $feature_popup_title=(exists $conf{crossing_link2}{index}{$pair}{feature_popup_title})? $conf{crossing_link2}{index}{$pair}{feature_popup_title}:$conf{feature_popup_title};
	if($feature_popup_title){
		my @kvs=split(/;/, $feature_popup_title);
		$feature_popup_title="\n";
		for my $kv(@kvs){
			$feature_popup_title.="<tspan>$kv</tspan>\n";	
		}
	}
	chomp $feature_popup_title;
	if($conf{crossing_link2}{position}{$up_id}{start}{y} > $conf{crossing_link2}{position}{$down_id}{start}{y}){
		if($up_id=~ /09:3303:59796/){
			print "1 $up_id,$down_id, $conf{crossing_link2}{position}{$up_id}{start}{y} > $conf{crossing_link2}{position}{$down_id}{start}{y}\n";
			my $tmp=$conf{crossing_link2}{position}{$up_id}{start}{y} - $conf{crossing_link2}{position}{$down_id}{start}{y};
			print "diff is $tmp\n"
		}
		my $up_id_tmp=$up_id;
		my $down_id_tmp=$down_id;
		$up_id=$down_id_tmp;
		$down_id=$up_id_tmp;
		if($up_id=~ /09:3303:59796/){print "2 $up_id,$down_id\n"}
	}
	my $cross_link_shift_y_pair_up=0;
	my $cross_link_shift_y_pair_low=0;
	if(exists $conf{crossing_link2}{index}{$pair}{cross_link_shift_y}){
		die "error:cross_link_shift_y = $conf{crossing_link2}{index}{$pair}{cross_link_shift_y} for $pair is error formats, should like +1:-1\n" if($conf{crossing_link2}{index}{$pair}{cross_link_shift_y}!~ /^([\+\d\.]+):([-\d\.]+)$/);
		$cross_link_shift_y_pair_up=$1*$sample_single_height/100;
		$cross_link_shift_y_pair_low=$2*$sample_single_height/100;
	}

	my $left_up_x = $conf{crossing_link2}{position}{$up_id}{start}{x};
	my $left_up_y = $conf{crossing_link2}{position}{$up_id}{start}{y};
	my $right_up_x = $conf{crossing_link2}{position}{$up_id}{end}{x};
	my $right_up_y = $conf{crossing_link2}{position}{$up_id}{end}{y};
	if($cross_link_anchor_pos=~ /^up_/){
		$left_up_y-=$conf{feature_setting2}{$up_id}{cross_link_shift_y} ;
		$left_up_y+= $cross_link_shift_y_pair_up;
		$right_up_y-=$conf{feature_setting2}{$up_id}{cross_link_shift_y} ;
		$right_up_y+=$cross_link_shift_y_pair_up;
	}elsif($cross_link_anchor_pos=~ /^low_/){
		$left_up_y+=$conf{feature_setting2}{$up_id}{cross_link_shift_y};
		$left_up_y+= $cross_link_shift_y_pair_up;
		$right_up_y+=$conf{feature_setting2}{$up_id}{cross_link_shift_y};
		$right_up_y+= $cross_link_shift_y_pair_up;
	}elsif($cross_link_anchor_pos !~ /^medium_/){
		die "error: 1not support cross_link_anchor_pos =$cross_link_anchor_pos yet~\n"
	}

	die "error: $down_id of crosslink is not in --list regions, please try to check it\n" if(not exists $conf{crossing_link2}{position}{$down_id}{start}{x});
	my $left_down_x = $conf{crossing_link2}{position}{$down_id}{start}{x};
	my $left_down_y = $conf{crossing_link2}{position}{$down_id}{start}{y};
	my $right_down_x = $conf{crossing_link2}{position}{$down_id}{end}{x};
	my $right_down_y = $conf{crossing_link2}{position}{$down_id}{end}{y};
	if($cross_link_anchor_pos=~ /_low/){
		$left_down_y+=$conf{feature_setting2}{$down_id}{cross_link_shift_y};
		$left_down_y+= $cross_link_shift_y_pair_low;
		$right_down_y+=$conf{feature_setting2}{$down_id}{cross_link_shift_y};
		$right_down_y+= $cross_link_shift_y_pair_low;
	}elsif($cross_link_anchor_pos=~ /_up/){
		$left_down_y-=$conf{feature_setting2}{$down_id}{cross_link_shift_y};
		$left_down_y+=$cross_link_shift_y_pair_low;
		$right_down_y-=$conf{feature_setting2}{$down_id}{cross_link_shift_y};
		$right_down_y+=$cross_link_shift_y_pair_low;
	}elsif($cross_link_anchor_pos !~ /_medium/){
		die "error: 2not support cross_link_anchor_pos=$cross_link_anchor_pos yet~\n"
	}
	die "error: got $cross_link_orientation for cross_link_orientation, but must be reverse or forward for $pair\n" if($cross_link_orientation!~ /reverse/i && $cross_link_orientation!~ /forward/i);
	my $cross_link_shape=(exists $conf{crossing_link2}{index}{$pair}{cross_link_shape})? $conf{crossing_link2}{index}{$pair}{cross_link_shape}:$conf{cross_link_shape};
	my $cross_link_orientation_ellipse=(exists $conf{crossing_link2}{index}{$pair}{cross_link_orientation_ellipse})? $conf{crossing_link2}{index}{$pair}{cross_link_orientation_ellipse}:$conf{cross_link_orientation_ellipse};
	my $cross_link_height_ellipse=(exists $conf{crossing_link2}{index}{$pair}{cross_link_height_ellipse})? $conf{crossing_link2}{index}{$pair}{cross_link_height_ellipse}:$conf{cross_link_height_ellipse};
	if($cross_link_height_ellipse!~ /^[\d\.]+,[\d\.]+$/){
		die "error: not support cross_link_height_ellipse=$cross_link_height_ellipse for $pair, right format should like 10,8\n";
	}

	if($cross_link_orientation_ellipse=~ /up/i){
		$cross_link_orientation_ellipse="0,1,1,0";
		$ytick_region_ratio=$up_percent_unit;
	}elsif($cross_link_orientation_ellipse=~ /down/i){
		$cross_link_orientation_ellipse="1,0,0,1";
		$ytick_region_ratio=$down_percent_unit;
	}else{
		die "error: not support cross_link_orientation_ellipse=$cross_link_orientation_ellipse for $up_id and $down_id\n"
	}

	my $title_clink="\n<g><title><tspan>$up_id -> $down_id</tspan>$feature_popup_title</title>\n";
#if($fts{$up_id}{sample} eq $fts{$down_id}{sample} && $fts{$up_id}{scf} eq $fts{$down_id}{scf} && $cross_link_shape=~ /ellipse/i){
	$cross_link_shape=~ s/\s+//g;
	if($cross_link_shape=~ /ellipse/i){
		die "error:cross_link_width_ellipse $cross_link_width_ellipse should <=1\n" if($cross_link_width_ellipse>1 || $cross_link_width_ellipse <0);
		my $correct_ellipse_coordinate=(exists $conf{crossing_link2}{index}{$pair}{correct_ellipse_coordinate})? $conf{crossing_link2}{index}{$pair}{correct_ellipse_coordinate}:$conf{correct_ellipse_coordinate};
#$left_up_x=(1-$cross_link_width_ellipse)/2*($right_up_x-$left_up_x);
		my $max=max($right_up_x-$left_up_x, $right_down_x-$left_down_x);
		my $min=max($right_up_x-$left_up_x, $right_down_x-$left_down_x);
		$cross_link_width_ellipse=($max*$cross_link_width_ellipse > $min)? $min:$max*$cross_link_width_ellipse;
		$right_up_x=$left_up_x+$cross_link_width_ellipse;
		$left_down_x=$right_down_x-$cross_link_width_ellipse;
		if($correct_ellipse_coordinate=~ /yes/){
			print "$left_up_x, $right_up_x, $left_down_x, $right_down_x\n";
			my @tmp=($left_up_x, $right_up_x, $left_down_x, $right_down_x);
			@tmp = sort {$a<=>$b} @tmp;
			($left_up_x, $right_up_x, $left_down_x, $right_down_x)=@tmp;
			my $flag=0;
			while($flag < ($right_down_x-$left_down_x)/10){
				$flag+=0.1;
			}
			$left_down_x-=$flag;
			$flag+=0.1;
			@tmp=($left_up_x, $right_up_x, $left_down_x, $right_down_x);
			@tmp = sort {$a<=>$b} @tmp;
			($left_up_x, $right_up_x, $left_down_x, $right_down_x)=@tmp;
			die "$left_up_x, $right_up_x, $left_down_x, $right_down_x\n"
		}elsif($correct_ellipse_coordinate!~ /no/){
			die "error:correct_ellipse_coordinate only support yes or no\n, but $correct_ellipse_coordinate\n";
		}
		my $r1=($right_down_x - $left_up_x)/2;
		my $r1_rev=($left_down_x - $right_up_x)/2;
		my ($r2, $r2_rev)=split(",", $cross_link_height_ellipse); # r1 and r2 is radius of elipse
#print "ytick_region_ratio is $ytick_region_ratio\n";
#$r2 = $r2*$id_line_height * $ytick_region_ratio;
#$r2_rev = $r2_rev*$id_line_height * $ytick_region_ratio;

			$r2 = $r2 * $ytick_region_ratio;
		$r2_rev = $r2_rev * $ytick_region_ratio;
		my $rotate=0;
		my $rotate_rev=0;
		my ($large_arc_flag, $sweep_flag, $large_arc_flag_rev, $sweep_flag_rev)=split(",", $cross_link_orientation_ellipse); #http://xahlee.info/js/svg_path_ellipse_arc.html

			$orders{$cross_link_order}.="$title_clink<path d=\"M$right_up_x $right_up_y L$left_up_x $left_up_y A$r1 $r2  $rotate $large_arc_flag $sweep_flag   $right_down_x $right_down_y L$left_down_x $left_down_y A$r1_rev $r2_rev $rotate_rev $large_arc_flag_rev $sweep_flag_rev $right_up_x $right_up_y Z\"  style=\"${crosslink_stroke_style}fill:$color;opacity:$cross_link_opacity\" /></g>";
#$orders{$cross_link_order}.="$title_clink<path d=\"M$right_up_x $right_up_y L$left_up_x $left_up_y A$r1 $r2  $rotate $large_arc_flag $sweep_flag   $right_down_x $right_down_y L$left_down_x $left_down_y A$r1_rev $r2_rev $rotate_rev $large_arc_flag_rev $sweep_flag_rev $right_up_x $right_up_y Z\"  style=\"fill:white;stroke:black;stroke-width:0.5;fill-opacity:0;stroke-opacity:1\" /></g>";
#print "downid is $down_id, up is is $up_id\n";
		next;
	}elsif($cross_link_shape=~ /quadrilateral/i){
		if($cross_link_orientation=~ /reverse/i){
			$color=(exists $conf{crossing_link2}{index}{$pair}{cross_link_color_reverse})? $conf{crossing_link2}{index}{$pair}{cross_link_color_reverse}:$conf{cross_link_color_reverse};
			$orders{$cross_link_order}.="$title_clink<polygon points=\"$left_up_x,$left_up_y $right_up_x,$right_up_y $left_down_x,$left_down_y $right_down_x,$right_down_y\" style=\"${crosslink_stroke_style}fill:$color;opacity:$cross_link_opacity\"/></g>\n"; #crossing link of features
		}elsif($cross_link_orientation=~ /forward/i){
			$orders{$cross_link_order}.="$title_clink<polygon points=\"$left_up_x,$left_up_y $right_up_x,$right_up_y $right_down_x,$right_down_y $left_down_x,$left_down_y\" style=\"${crosslink_stroke_style}fill:$color;opacity:$cross_link_opacity\"/></g>\n"; #crossing link of features
		}else{
			die "error: not support cross_link_orientation=$cross_link_orientation\n";
		}
	}elsif($cross_link_shape eq "w"){
		print "wait w\n";
		die "not support w yet\n";
	}elsif($cross_link_shape=~ /line/i){
#cross_link_orientation_line
		my $cross_link_orientation_line=(exists $conf{crossing_link2}{index}{$pair}{cross_link_orientation_line})? $conf{crossing_link2}{index}{$pair}{cross_link_orientation_line}:$conf{cross_link_orientation_line};
		my $cross_link_height_line=(exists $conf{crossing_link2}{index}{$pair}{cross_link_height_line})? $conf{crossing_link2}{index}{$pair}{cross_link_height_line}:$conf{cross_link_height_line};
		my @cross_link_orientation_line_list = split(/,/, $cross_link_orientation_line);
		if(@cross_link_orientation_line_list!=2){
			die "error: cross_link_orientation_line=$cross_link_orientation_line ,error format. example: start,end or end,start ~\n"
		}

		my ($ss, $ee) = @cross_link_orientation_line_list;
		my ($x1,$y1,$x2,$y2);
		if($ss=~ /start/i){
			$x1=$left_up_x;
			$y1=$left_up_y;
		}elsif($ss=~ /medium/i){
			$x1=($right_up_x+$left_up_x)/2;
			$y1=($right_up_y+$left_up_y)/2;
		}elsif($ss=~ /end/i){
			$x1=$right_up_x;
			$y1=$right_up_y;
		}else{
			die "error: only strat or end or medium, but get $ss,$ee\n"
		}

		if($ee=~ /start/i){
			$x2=$left_down_x;
			$y2=$left_down_y;
		}elsif($ee=~ /medium/i){
			$x2=($right_down_x+$left_down_x)/2;
			$y2=($right_down_y+$left_down_y)/2;
		}elsif($ee=~ /end/i){
			$x2=$right_down_x;
			$y2=$right_down_y;
		}else{
			die "error: only strat or end or medium, but get $ss,$ee\n"
		}
		my $stroke_width=$cross_link_height_line*$id_line_height;
		$orders{$cross_link_order}.="$title_clink<line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" style=\"fill:$color;stroke:$color;stroke-width:$stroke_width;opacity:$cross_link_opacity\" /></g>\n"; #crossing link of features
	}else{
		die "error:not support cross_link_shape=$cross_link_shape: for $up_id and $down_id, only support quadrilateral or w or ellipse or line\n";
	}




}



## draw legend
my $legend_num=0;
my %legend_color_num;
for my $f(keys %{$conf{feature_setting2}}){
	if(exists $conf{feature_setting2}{$f}{legend_label}){
		if(exists $legend_color_num{$conf{feature_setting2}{$f}{feature_color}}){
			if($legend_color_num{$conf{feature_setting2}{$f}{feature_color}} ne $conf{feature_setting2}{$f}{legend_label}){
				die "error: one $conf{feature_setting2}{$f}{feature_color} -> more than one different legend_label\n";
			}
		}else{
			$legend_color_num{$conf{feature_setting2}{$f}{feature_color}}=$conf{feature_setting2}{$f}{legend_label};
		}

	}
}
$legend_num=keys %legend_color_num;

#print "legend_num is $legend_num\n";
#my $top_margin_legend;
#my $legend_single_arrow_height = $common_size; # 和sample name一样的字体大小，字体大小几乎等同同等像素的宽高
#my $limit = 0.8;
#if($legend_single_arrow_height*$legend_num < $svg_height*$limit){
#	$top_margin_legend = $svg_height - $legend_single_arrow_height*$legend_num *1.1; #第一个legend顶部的y轴
#}else{
#	$legend_single_arrow_height = $svg_height*$limit/$legend_num;# 每行legend的高度
#	$top_margin_legend = (1-$limit)/2*$svg_height;
#}
#my $legend_font_size = $legend_single_arrow_height * 0.9;

#my $legend_max_length=0;
#foreach my $legend(keys %{$conf{feature_setting}{legend_col}}){
#	if(length($legend) >$legend_max_length){
#		$legend_max_length = $length($legend);
#	}
#}

if($conf{display_legend}=~ /yes/i){
	print "lengend start\n";
	my $legend_arrow_height = $id_line_height*$conf{feature_height_ratio}*$conf{legend_height_ratio};
	my $legend_font_size = $conf{legend_font_size}; #legend中文字字体大小
		my $top_margin_legend = ($svg_height - ($legend_arrow_height * $legend_num + ($legend_num-1)*$legend_arrow_height*$conf{legend_height_space}))/2;
	my $legend_single_arrow_height = $legend_arrow_height;

	my $legend_width_margin = $conf{legend_width_margin};
	my $legend_width_textpercent = $conf{legend_width_textpercent};
	my $legend_arrow_width = (1-$legend_width_margin*2)*(1-$legend_width_textpercent)*$svg_width*$legend_width_ratio;
	my $text_x = (1-$legend_width_ratio)*$svg_width+$legend_width_margin*$legend_width_ratio*$svg_width+$legend_arrow_width*1.2;
	my $text_y = $top_margin_legend + 0.95*$legend_arrow_height ;
	my $arrow_x = (1-$legend_width_ratio)*$svg_width+$legend_width_margin*$legend_width_ratio*$svg_width*1.1;
	my $arrow_y = $top_margin_legend;
#my $legend_arrow_height = $legend_single_arrow_height * 0.8;
	foreach my $legend_color(sort keys %legend_color_num){
		my $legend = $legend_color_num{$legend_color};
## draw_gene 函数需要重写，输入起点的xy坐标，正负链等信息即可
# 先用方块代替arrow
		my @arr_cols=split(/,,/, $legend_color);
		my $arrow_col_start;
		my $arrow_col_end;
#print "legend arr_cols is @arr_cols\n";
		if(@arr_cols==2){
#print "aisis $conf{feature_setting}{legend_col}{$legend},@arr_cols\n";
			$arrow_col_start = $arr_cols[0];
			$arrow_col_end = $arr_cols[1];
#my $arrow_color_id = $conf{feature_setting}{legend_col}{$legend};
			my $arrow_color_id = $legend_color;
			$arrow_color_id=~ s/,/-/g;
			$arrow_color_id=~ s/\)/-/g;
			$arrow_color_id=~ s/\(/-/g;
			$svg.="
				<defs>
				<linearGradient id=\"$arrow_color_id\" x1=\"0%\" y1=\"0%\" x2=\"0%\" y2=\"100%\">
				<stop offset=\"0%\" style=\"stop-color:$arrow_col_start;stop-opacity:1\"/>
				<stop offset=\"50%\" style=\"stop-color:$arrow_col_end;stop-opacity:1\"/>
				<stop offset=\"100%\" style=\"stop-color:$arrow_col_start;stop-opacity:1\"/>
				</linearGradient>
				</defs>
				<g style=\"fill:none\">
				<rect x=\"$arrow_x\" y=\"$arrow_y\" width=\"$legend_arrow_width\" height=\"$legend_arrow_height\" style=\"fill:url(#$arrow_color_id);stroke:black;stroke-width:1;fill-opacity:1;stroke-opacity:1\" />
				</g>";
		}else{
			$svg.="<rect x=\"$arrow_x\" y=\"$arrow_y\" width=\"$legend_arrow_width\" height=\"$legend_arrow_height\" style=\"fill:$legend_color;stroke:$conf{legend_stroke_color};stroke-width:$conf{legend_stroke_width};fill-opacity:1;stroke-opacity:1\" />";
		}
## draw legend
		$svg.="<text x=\"$text_x\" y=\"$text_y\" font-size=\"${legend_font_size}px\" fill=\"black\" text-anchor='start'>$legend</text>";
		$arrow_y += $legend_single_arrow_height +$legend_arrow_height*$conf{legend_height_space};
		$text_y += $legend_single_arrow_height +$legend_arrow_height*$conf{legend_height_space};
## draw legend

	}
#legend外围的线框
#my $legend_rect_width = (1-$legend_width_margin*2)*$svg_width*$legend_width_ratio * 1.1;
#my $legend_rect_height = $svg_height*$legend_height_percent * 1.04;
#my $legend_rect_x = (1-$legend_width_ratio)*$svg_width+$legend_width_margin*$legend_width_ratio*$svg_width *0.9;
#my $legend_rect_y = $top_margin_legend;
#$svg.="<rect x=\"$legend_rect_x\" y=\"$legend_rect_y\" width=\"$legend_rect_width\" height=\"$legend_rect_height\" style=\"fill:none;stroke:black;stroke-width:1;fill-opacity:0;stroke-opacity:1\" />"; #不画这条线框了
}


#刻度尺
if($conf{scale_display}=~ /yes/i){
	my @scales=split(/_/, $conf{scale_position});
	foreach my $scale(@scales){
		print "disply scale\n";
		my $x_start_scale=$left_distance_init;
#my $x_end_scale=$cluster_width_ratio*$svg_width + $x_start_scale - $space_len;
		my $x_end_scale=$cluster_width_ratio*$svg_width + $x_start_scale;
		my $y_scale;
		my $y_tick_shift=-3;
		my $font_size=$conf{scale_tick_fontsize};
		my $tick_height=$conf{scale_tick_height}* $svg_height;
		if($scale=~ /up/){
			$y_scale=$top_bottom_margin/2* 0.5 * (1-$conf{scale_padding_y})* $svg_height;
#$y_tick_shift=-$conf{scale_tick_padding_y};
		}else{
			$y_scale=(1- $top_bottom_margin/2*(1-$conf{scale_padding_y})) * $svg_height;
			$y_tick_shift=$conf{scale_tick_padding_y};
			$tick_height=-$tick_height;
		}
		$orders{$conf{scale_order}}.="<line x1=\"$x_start_scale\" y1=\"$y_scale\" x2=\"$x_end_scale\" y2=\"$y_scale\" style=\"stroke:$conf{scale_color};stroke-width:$conf{scale_width}\"/>\n"; #main line
		my $unit_scale=$conf{scale_ratio}*$ratio; # bp
		my $ticks=int($cluster_width_ratio*$svg_width/$unit_scale);
		#die "tick is $ticks =int($cluster_width_ratio*$svg_width/$unit_scale)\n";
		print "ticks number is $ticks\n";
		my $tick_y1= $y_scale + $tick_height; #single tick hegith
			my $tick_y2= $y_scale ;
		my $tick_label_y=$y_scale+$y_tick_shift;
		my $scale_start=1;
		if(scalar(keys %gff) == 1){
			my @ss=keys %gff;
			$scale_start = $start_once if(scalar (keys %{$gff{$ss[0]}{chooselen_single}}) == 1)
		}
		foreach my $tick(0..$ticks){
			my $tick_x=$tick*$unit_scale + $x_start_scale;
			my $tick_label=$tick*$conf{scale_ratio};
			last if( ($max_length - $tick_label) < $conf{scale_ratio} );
			$tick_label+=($scale_start-1);
			$tick_label=&format_scale($tick_label);
			$orders{$conf{scale_order}}.="<line x1=\"$tick_x\" y1=\"$tick_y1\" x2=\"$tick_x\" y2=\"$tick_y2\" style=\"stroke:$conf{scale_color};stroke-width:$conf{scale_width};opacity:$conf{scale_tick_opacity}\"/>\n"; # ticks
			$orders{$conf{scale_order}}.= "<text x=\"$tick_x\" y=\"$tick_label_y\" font-size=\"${font_size}px\" fill=\"$conf{scale_color}\"  text-anchor='middle' font-family=\"Times New Roman\">$tick_label</text>\n"; # label of feature

		}
		if($cluster_width_ratio*$svg_width % $unit_scale){
			$orders{$conf{scale_order}}.="<line x1=\"$x_end_scale\" y1=\"$tick_y1\" x2=\"$x_end_scale\" y2=\"$tick_y2\" style=\"stroke:$conf{scale_color};stroke-width:$conf{scale_width};opacity:$conf{scale_tick_opacity}\"/>\n"; # last tick
			
				my $last_tick_label=&format_scale($max_length+$scale_start-1);
			$last_tick_label.="bp";

			$orders{$conf{scale_order}}.= "<text x=\"$x_end_scale\" y=\"$tick_label_y\" font-size=\"${font_size}px\" fill=\"$conf{scale_color}\"  text-anchor='middle' font-family=\"Times New Roman\">$last_tick_label</text>\n"; # label of feature

		}

	}
}

open SVG,">$outdir/$prefix.svg" or die "$!";
print SVG "$svg";
for my $order(sort {$a<=>$b}keys %orders){
	print "order is $order\n";
	print SVG "\n$orders{$order}\n";
}
print SVG "</svg>";
close SVG;
my $rm_title="set -vex;sed -e 's/^\\s*<g>.*//' -e 's/<\\/g>//' -e 's/^<tspan.*//'  $outdir/$prefix.svg >$outdir/$prefix.notitle.svg";
`$rm_title`;
die "\nerror:$rm_title\n\n" if($?);

print "\noutfile is  $outdir/$prefix.svg and $outdir/$prefix.notitle.svg\n";
print "\nif you want png or pdf format,you could use convert or cairosvg to convert svg to pdf or png:\n\tconvert  -density $conf{pdf_dpi} $outdir/$prefix.svg $outdir/$prefix.png\n\tconvert -density $conf{pdf_dpi} $outdir/$prefix.svg $outdir/$prefix.dpi$conf{pdf_dpi}.pdf\n\n";

&jstohtml("$Bin/svg-pan-zoom.js","$outdir/$prefix");




sub jstohtml(){
	my ($zoom,$prefix)=@_;
	if(-f $zoom){
		#my $svg="<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\" width=\"$svg_width\" height=\"$svg_height\" style=\"background-color:$conf{svg_background_color};\">\n";
		open OUT,">$prefix.html";
		print OUT "<!DOCTYPE html>\n<html>\n<head>\n<script>\n";
		my $zoom_js=`cat $zoom`; chomp $zoom_js;
		print OUT "$zoom_js\n";
		print OUT "</script>\n</head>\n<body>\n<h1>$prefix, you can zoom in/out or drag, thanks https://github.com/ariutta/svg-pan-zoom</h1>\n<div id='container' style=\"width: ${svg_width}px; height: ${svg_height}px; border:1px solid black;\">\n<svg id='demo-tiger' xmlns='http://www.w3.org/2000/svg' style='display: inline; width: inherit; min-width: inherit; max-width: inherit; height: inherit; min-height: inherit; max-height: inherit;' viewBox=\"0 0 $svg_width $svg_height\" version=\"1.1\">\n";
		my $svg=`sed '1d' $prefix.svg`;chomp $svg;
		print OUT "$svg\n";
		print OUT " </div>
    <button id=\"enable\" style='display:none'>enable</button>
    <button id=\"disable\" style='display:none'>disable</button>

    <script>
      // Don't use window.onLoad like this in production, because it can only listen to one function.
      window.onload = function() {
        // Expose to window namespase for testing purposes
        window.zoomTiger = svgPanZoom('#demo-tiger', {
          zoomEnabled: true,
          controlIconsEnabled: true,
          fit: true,
          center: true,
          // viewportSelector: document.getElementById('demo-tiger').querySelector('#g4') // this option will make library to misbehave. Viewport should have no transform attribute
        });

        document.getElementById('enable').addEventListener('click', function() {
          window.zoomTiger.enableControlIcons();
        })
        document.getElementById('disable').addEventListener('click', function() {
          window.zoomTiger.disableControlIcons();
	alert('ddd')
        })
      };
    </script>

  </body>

</html>";
		close OUT;
		print "$zoom exists,\n	so output $prefix.html, which you can zoom in/out or drag, thanks https://github.com/ariutta/svg-pan-zoom\n\n";
	}else{
		print "$zoom not exists,\n	so not output $prefix.html which you can zoom in/out or drag, thanks https://github.com/ariutta/svg-pan-zoom\n\n";
	}
}

