from osgeo import gdal
import numpy as np
import glob, re
import argparse


def splice(input_folder, output_path):
    '''
    - 将一组tif小图拼接为tif大图。小图的文件名格式形如`slice21_55675x47791_10000_29970x29970.tif`
    '''
    # 获取所有tif小图的文件路径
    tile_files = glob.glob(input_folder + '/*.tif')

    # 读取第一张小图获取基本信息
    first_tile_path= filter(lambda x: "0x0.tif" in x, tile_files).__next__()
    first_tile = gdal.Open(first_tile_path)
    tile_width = first_tile.RasterXSize
    tile_height = first_tile.RasterYSize
    dtype = first_tile.GetRasterBand(1).DataType

    # 创建大图
    origin_width= int(first_tile_path.split('_')[-3].split('x')[0])
    origin_height= int(first_tile_path.split('_')[-3].split('x')[1])
    driver = gdal.GetDriverByName("GTiff")
    merged_dataset = driver.Create(output_path, origin_width, origin_height, 3, dtype)

    # 设置大图的地理信息和投影信息[对象左上角像素的X地理坐标，单个像素的宽度(米)，图像的旋转，对象左上角像素的y地理坐标，图像的旋转，单个像素的宽度(米)]（可根据实际情况调整）
    #geo_transform = [0, 1, 0, 0, 0, 1]
    #merged_dataset.SetGeoTransform(geo_transform)

    # 逐个拼接小图
    pattern = r'_(\d+)x(\d+)\.'
    for tile_file in tile_files:
        # 获取小图的位置信息
        match = re.search(pattern, tile_file)
        if match:
            x_offset = int(match.group(1))
            y_offset = int(match.group(2))
            # 读取小图数据
            tile_data = gdal.Open(tile_file).ReadAsArray()
            # 写入大图对应位置
            merged_dataset.WriteRaster(x_offset, y_offset, tile_width, tile_height, tile_data)

    # 设置NoData值（可根据实际情况调整）
    for i in range(1, 4):
        merged_dataset.GetRasterBand(i).SetNoDataValue(0)

    # 保存大图
    merged_dataset.FlushCache()
    merged_dataset = None

def main():
    parser = argparse.ArgumentParser(description='Splice a group of tif imgs to a big tif img.')
    parser.add_argument('--input_dir', required=True, help='Input directory path')
    parser.add_argument('--output_path', required=True, help='Output directory path')

    args = parser.parse_args()

    splice(args.input_dir, args.output_path)

if __name__ == '__main__':
    main()