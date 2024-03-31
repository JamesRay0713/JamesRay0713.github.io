# 做AI项目期间，一些实用的小工具

def show_a_img_in_COCO(
        path_anno_json="/paddle/PaddleDetection/dataset/mangrove/annotations/train_coco.json", 
        dir_img="/paddle/PaddleDetection/dataset/mangrove/train_images/", 
        img_id=1
    ):
    '''- 在COCO类型的数据集中，指定一张附带锚框的图片来显示。
    path_anno_json: 标注文件的路径,
    dir_img: 图片存放的目录，
    img_id: 要显示图片的id
    '''
    from pycocotools.coco import COCO
    from PIL import Image, ImageDraw
    
    coco = COCO(path_anno_json)
    image_id = coco.getImgIds()[img_id]
    image_info = coco.loadImgs(image_id)[0]
    image_path = f"{image_info['file_name']}"
    annotations = coco.loadAnns(coco.getAnnIds(imgIds=image_id))
    image = Image.open(dir_img +image_path).convert('RGB')

    # 画
    draw = ImageDraw.Draw(image)
    for annotation in annotations:
        bbox = annotation['bbox']
        draw.rectangle([bbox[0], bbox[1], bbox[0] + bbox[2], bbox[1] + bbox[3]], outline=(255, 0, 0), width=2)
    image.show()