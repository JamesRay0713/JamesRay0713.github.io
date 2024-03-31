# 注：COCO格式的bbox为[x,y,w,h], 其中x,y是边界框左上角的x,y坐标。
import os, json, re
import argparse

def main():
    parser = argparse.ArgumentParser(description='modify coordinate of bboxes from sub-images into the origin-image.')
    parser.add_argument('--bbox_path', required=True, help='the file need to deal with')
    parser.add_argument('--origin_img_path', required=True, help='the path of image before slice')

    args = parser.parse_args()
    origin_img= args.origin_img_path
    ori_json= args.bbox_path
    new_json= f"{os.path.dirname(ori_json)}/bbox_origin_img.json"

    with open(ori_json) as f:
        ori_lis= json.load(f)
    new_lis= []

    for dic in ori_lis:
        dic['image_id']= 0

        pattern = r'_(\d+)x(\d+)\.'
        match = re.search(pattern, dic['file_name'])
        if match:
            coordx = int(match.group(1))
            coordy = int(match.group(2))
            dic['bbox'][0]+= coordx
            dic['bbox'][1]+= coordy

        dic['file_name']= origin_img

        new_lis.append(dic)

    with open(new_json, 'w') as f:
        json.dump(new_lis, f)

if __name__ == '__main__':
    main()