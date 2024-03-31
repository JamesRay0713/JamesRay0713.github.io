import math
import os
from PyQt5.QtGui import QImage

from tqdm import tqdm

import argparse

def main():
    parser = argparse.ArgumentParser(description='Split images.')
    parser.add_argument('--input_dir', required=True, help='Input directory path')
    parser.add_argument('--output_dir', required=True, help='Output directory path')
    parser.add_argument('--subimg_size', type=int, default=640, help='Subimage size')
    parser.add_argument('--overlap', type=float, default=0.1, help='Overlap rate')

    args = parser.parse_args()

    input_dir = args.input_dir
    output_dir= args.output_dir
    subimg_size = args.subimg_size
    if args.overlap== 0.0:
        overlap= 50/subimg_size
    else:
        overlap= args.overlap

    # 这里的重叠率默认下不是0.0，而是50pix对应的重叠比率。
    origin_img_size= slice_image(input_dir, output_dir, slice_size=subimg_size, overlap_rate=overlap)
    print(f'切割后的图集存放于`{output_dir}`\n')

def slice_image(image_path_dir, out_dir, out_type='', slice_size=640, overlap_rate=0.1):
    """
    使用 pyQt5的Qimage 实现高分辨率图片的切片功能。

    Parameters:
    - image_path_dir (str): 输入图片路径，只能是文件夹形式。
    - out_dir (str): 切片输出路径。其下是原图命名的子目录，再下才是子图集合。
    - out_type (str): 输出图片格式。默认下跟随原图格式，也可自定义为'.tif, .jpg, .png'等。.png涉及格式转换，速度最慢；.tif在AI模型训练中不支持, 速度适中; .jpg, 压缩得最厉害，也最快。
    - slice_size (int): 切片尺寸
    - overlap_rate (float): 重叠区域比例

    Note:
    - 切分后子图的命名格式: 切片序号+ 原图宽高+ 子图尺寸+ 子图左上角像素在原图的宽高坐标
    - img = cv2.imread(image_path)
    """
    img_size=(0,0)
    if not os.path.exists(out_dir):
        os.makedirs(out_dir)

    image_path_list= os.listdir(image_path_dir)
    n=0
    for img_path in image_path_list:
        
        img_name_suff= os.path.splitext(img_path)
        img_name= img_name_suff[0]
        img_type= img_name_suff[1]
        if out_type!='':
            img_type= out_type
        image_path= os.path.join(image_path_dir, img_path)
        out_path= os.path.join(out_dir, img_name)
        if not os.path.exists(out_path):
            os.makedirs(out_path)
        else:
            os.system(f'rm {out_path}/*')
        
        print(f"原图{n}-- 加载中......")
        img = QImage(image_path)
        height, width = img.height(), img.width()
        img_size=(height, width)

        step = int(slice_size * (1 - overlap_rate))
        rows = math.ceil((height - slice_size) / step + 1)
        cols = math.ceil((width - slice_size) / step + 1)
        print(f"原图{n}-- 处理[{img_path}, {width}x{height}], 子图:{slice_size}x{slice_size}, 切片数: {rows * cols} \nprocessing......")
        n+=1

        m=0
        for i in tqdm(range(rows), desc="Processing Rows"):
            start_x = i * step  # 高。注，这里一开始搞错了，应该用`start_y`指代`高`的
            if start_x + slice_size> height:
                start_x = height - slice_size

            for j in tqdm(range(cols), desc="Processing Columns", leave=False):
                start_y = j * step  # 宽
                if start_y + slice_size> width:
                    start_y = width - slice_size

                slice_img = img.copy(start_y, start_x, slice_size, slice_size)

                out_name = f"slice{i*cols+j}_{width}x{height}_{slice_size}_{start_y}x{start_x}{img_type}"
                out_file = os.path.join(out_path, out_name)
                slice_img.save(out_file)
                m+=1
    return img_size

if __name__ == '__main__':
    main()
