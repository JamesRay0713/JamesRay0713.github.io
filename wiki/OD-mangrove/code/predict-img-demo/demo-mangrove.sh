# 使用方法：①把你想分析的原图放到任意一个空文件夹，该文件夹下只能有一张图片，复制文件夹的路径。
#           ②打开Ubuntu，使用命令：`bash /home/james/obj_OD/demo_mangrove/demo-mangrove.sh --input-dir "文件夹路径"`(一定是英文双引号)
#           ③运行，半分钟左右桌面得到一个【红树林目标检测可视化结果】文件夹。

# 准备参数
input_dir="D:\【003】红树林核查识别工作\惠东正射2\origin_test"
#input_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input-dir)
      input_dir=$2
      shift
      ;;
    *)      # 忽略其他参数
      shift
      ;;
  esac
done
# 准备环境
cd $(dirname "$0")

# 推理前的图片切割，640*640，0.1，存到output_dir
input_dir=$(echo $input_dir | sed -e 's#\\#/#g' -e 's#^\([A-Z]\):#/mnt/\L\1#')
input_file=$(ls $input_dir | tr ' ' '\n' | grep ".tif$")
output_dir=/home/james/obj_OD/demo_mangrove/sub_images

echo -e "切割耗时: \n"
time python split_app.py --input_dir=$input_dir --output_dir=$output_dir

# 切割后的所有子图全都在容器中运行得到框图预测，结果存到 output_dir
test_img_dir=$output_dir/$(basename $input_file .tif)
test_img_dir_container=$(echo "/paddle/"$(echo $test_img_dir | awk -F'/' '{for (i=5; i<=NF; i++) printf "%s%s", $i, (i<NF ? "/" : ""); print ""}'))

container_status=$(docker inspect -f '{{.State.Status}}' paddleGP)
if [ "$container_status" == "exited" ]; then
docker start paddleGP
fi
docker exec -it paddleGP python /paddle/PaddleDetection/deploy/python/infer.py \
--model_dir=/paddle/PaddleDetection/deploy_inference_model/ppyoloe_crn_l_80e_sliced_visdrone_640_025 \
--image_dir=$test_img_dir_container \
--output_dir=/paddle/output/ \
--device=GPU \
--save_results --save_images True \
--batch_size 64

sudo rm -r $output_dir
output_dir=/home/james/obj_OD/output

# 后处理1：修正预测框坐标到一张大图（存放于与bbox.json同目录下的bbox_origin_img.json）。TODO: 如何后续利用？
bbox_json=$output_dir/bbox.json
bbox_num=$(grep -o 'score' $bbox_json |wc -l)
python modify_bbox_json.py --bbox_path $bbox_json --origin_img_path $input_dir/$input_file

final_dir=/mnt/c/Users/ASUS/Desktop/红树林目标检测可视化结果
if [ ! -d "$final_dir" ]; then
    mkdir "$final_dir"
fi
#sudo mv $output_dir/*.json $final_dir 暂时不用

# 后处理2：把带预测框的所有小图拼接一张大图，并导出指定位置
echo -e "\n将一共识别出的" $bbox_num "棵树木的预测框数据合并到一张大图..."
final_path=$final_dir"/"$(basename $input_file .tif)"_共"$bbox_num"株.tif"

time python splice.py --input_dir $output_dir --output_path $final_path

sudo rm -r $output_dir
mkdir $output_dir
echo "结果存放于桌面的【红树林目标检测可视化结果】目录中。原图共识别出"$bbox_num"棵树木。"
