#!/bin/bash
# 训练数据目录结构规范：混合风格 → voc风格
#   规范前：data_dir目录下包含所有的png图片文件和xml标注文件
#   规范后: voc_dir目录下，有./images/归入所有图片；有./annotations/归入所有标注；有./label_list.txt存放数据的标签集合；有train.txt\val.txt(每行的格式为`images/img1.png annotations/img1.xml`)

# 事先指定好的4个变量
subfix=png
data_dir=dataset/mangrove_sliced
voc_dir=dataset/mangrove_voc
train_percent=80   # 切分给训练集的占比

mkdir -p $voc_dir/annotations
mkdir -p $voc_dir/images

cp $data_dir/*.xml $voc_dir/annotations/
cp $data_dir/*.$subfix $voc_dir/images/

echo "tree" > ${voc_dir}/label_list.txt

ls $voc_dir/images/*.$subfix | shuf > $data_dir/all_image_list.txt 
#awk -F"/" '{print $NF}' $data_dir/all_image_list.txt | awk -F".tif" '{print $1}'  | awk -v voc_dir=$voc_dir -v subfix=$subfix -F"\t" '{print voc_dir"/images/"$1"."subfix" "voc_dir"/annotations/"$1".xml"}' > $data_dir/all_list.txt
awk -F"/" '{print $NF}' $data_dir/all_image_list.txt | awk -F"."$subfix '{print $1}'  | awk -v subfix=$subfix -F"\t" '{print "images/"$1"."subfix" annotations/"$1".xml"}' > $data_dir/all_list.txt

nums=$(wc -l < $data_dir/all_image_list.txt)
nums_train=$((nums*$train_percent/100))     # 向下取整
nums_valid=$((nums-nums_train))
head -n $nums_train $data_dir/all_list.txt > $voc_dir/train.txt
tail -n $nums_valid $data_dir/all_list.txt > $voc_dir/val.txt

rm $data_dir/all_list.txt
rm $data_dir/all_image_list.txt
