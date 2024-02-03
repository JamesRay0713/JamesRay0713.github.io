#!/bin/bash
# 训练数据目录结构规范：voc风格 → coco风格

# 事先指定好的2个变量
voc_dir=dataset/mangrove_voc
coco_dir=dataset/mangrove_coco

rm -r $coco_dir
mkdir -p ${coco_dir}/annotations

# step1: 图片按训练、验证、测试集合分组（继承自voc）
for txt_name in "train" "val" "test"; do
    txt_file=${voc_dir}/${txt_name}.txt
    if [ -e "$txt_file" ]; then
        img_dir="${coco_dir}/${txt_name}_images/"
        mkdir -p $img_dir
        awk -v voc_dir="${voc_dir}" '{print voc_dir "/" $1}' "${txt_file}" | xargs cp -t ${img_dir}
        echo "* * * copy done: ${img_dir}"

# step2: 把多个xml文件合成1个json文件
#        注：这里修改了tools/x2coco.py中的voc_get_label_anno()函数，见line198
        python ./x2coco.py \
            --dataset_type voc \
            --voc_anno_dir ${voc_dir}/annotations \
            --voc_anno_list ${voc_dir}/${txt_name}.txt \
            --voc_label_list ${voc_dir}/label_list.txt \
            --voc_out_name ${coco_dir}/annotations/${txt_name}_coco.json
        echo "* * * transfer done: ${coco_dir}/annotations/${txt_name}_coco.json"
    fi
done