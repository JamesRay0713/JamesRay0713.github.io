import math
import os
import sys

from PyQt5.QtCore import QCoreApplication, Qt
from PyQt5.QtGui import QImage, QPixmap
from PyQt5.QtWidgets import (QApplication, QFileDialog, QLabel, QLineEdit,
                             QProgressBar, QPushButton, QTextEdit, QVBoxLayout,
                             QWidget)
from tqdm import tqdm


class ImageProcessingApp(QWidget):
    def __init__(self, default_args):
        super().__init__()
        self.default_args= default_args

        self.init_ui()

    # 在 init_ui 函数中为输入框设置默认值
    def init_ui(self):
        layout = QVBoxLayout()

        self.label_path1 = QLabel("原图目录:")
        self.label_path2 = QLabel("切分后存放目录:")
        self.label_out_type= QLabel("输出图片格式:")
        self.label_subimage_size = QLabel("子图尺寸:")
        self.label_overlap_rate = QLabel("重叠比率:")

        self.edit_path1 = QLineEdit()
        self.edit_path1.setPlaceholderText(self.default_args[0])

        self.edit_path2 = QLineEdit()
        self.edit_path2.setPlaceholderText(self.default_args[1])

        self.edit_out_type = QLineEdit()
        self.edit_out_type.setPlaceholderText(self.default_args[2])

        self.edit_subimage_size = QLineEdit()
        self.edit_subimage_size.setPlaceholderText(self.default_args[3])

        self.edit_overlap_rate = QLineEdit()
        self.edit_overlap_rate.setPlaceholderText(self.default_args[4])

        self.btn_browse_path1 = QPushButton("浏览")
        self.btn_browse_path1.clicked.connect(self.browse_path1)

        self.btn_browse_path2 = QPushButton("浏览")
        self.btn_browse_path2.clicked.connect(self.browse_path2)

        self.btn_start = QPushButton("开始")
        self.btn_start.clicked.connect(self.start_processing)

        self.text_output = QTextEdit()

        self.root_progress_bar = QProgressBar()
        self.root_progress_bar.setFormat("总进度: %p%")
        self.main_progress_bar = QProgressBar()
        self.main_progress_bar.setFormat("行进度: %p%")
        self.sub_progress_bar = QProgressBar()
        self.sub_progress_bar.setFormat("列进度: %p%")

        layout.addWidget(self.label_path1)
        layout.addWidget(self.edit_path1)
        layout.addWidget(self.btn_browse_path1)

        layout.addWidget(self.label_path2)
        layout.addWidget(self.edit_path2)
        layout.addWidget(self.btn_browse_path2)

        layout.addWidget(self.label_out_type)
        layout.addWidget(self.edit_out_type)

        layout.addWidget(self.label_subimage_size)
        layout.addWidget(self.edit_subimage_size)

        layout.addWidget(self.label_overlap_rate)
        layout.addWidget(self.edit_overlap_rate)

        layout.addWidget(self.btn_start)
        layout.addWidget(self.text_output)
        layout.addWidget(self.main_progress_bar)
        layout.addWidget(self.sub_progress_bar)
        layout.addWidget(self.root_progress_bar)

        self.setLayout(layout)


    def browse_path1(self):
        path = QFileDialog.getExistingDirectory(self, "选择原图目录", "")
        if path:
            self.edit_path1.setText(path)
            QApplication.processEvents()

    def browse_path2(self):
        path = QFileDialog.getExistingDirectory(self, "选择存放目录", "")
        if path:
            self.edit_path2.setText(path)


    def slice_image(self, image_path_dir, out_dir, out_type='', slice_size=640, overlap_rate=0.2):
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
        if not os.path.exists(out_dir):
            os.makedirs(out_dir)
        image_path_list= os.listdir(image_path_dir)
        file_num=0
        for img_path in image_path_list:
            if '.' in img_path:
                file_num+=1
        n=0
        for img_path in image_path_list:
            if '.' not in img_path:
                continue            
            img_name_suff= os.path.splitext(img_path)
            img_name= img_name_suff[0]
            img_type= img_name_suff[1]
            if out_type != '':
                img_type= out_type
            image_path= os.path.join(image_path_dir, img_path)
            out_path= os.path.join(out_dir, img_name)
            if not os.path.exists(out_path):
                os.makedirs(out_path)
            
            self.text_output.append(f"原图{n}-- 加载中......")
            img = QImage(image_path)
            height, width = img.height(), img.width()

            step = int(slice_size * (1 - overlap_rate))
            rows = math.ceil((height - slice_size) / step + 1)
            cols = math.ceil((width - slice_size) / step + 1)
            self.text_output.append(f"原图{n}-- 处理[{img_path}, {width}x{height}], 子图:{slice_size}x{slice_size}, 切片数: {rows * cols} \nprocessing......")
            n+=1

            m=0
            for i in tqdm(range(rows), desc="Processing Rows"):
                start_x = i * step  # 高。注，这里一开始搞错了，应该用`start_y`指代`高`的
                if start_x + slice_size> height:
                    start_x = height - slice_size
                # 完成行数进度条
                self.main_progress_bar.setValue(int((i + 1)/rows*100))

                for j in tqdm(range(cols), desc="Processing Columns", leave=False):
                    start_y = j * step  # 宽
                    if start_y + slice_size> width:
                        start_y = width - slice_size
                    # 完成列数进度条
                    self.sub_progress_bar.setValue(int((j+1)/cols*100))

                    slice_img = img.copy(start_y, start_x, slice_size, slice_size)

                    out_name = f"slice{i*cols+j}_{width}x{height}_{slice_size}_{start_y}x{start_x}{img_type}"
                    out_file = os.path.join(out_path, out_name)
                    slice_img.save(out_file)
                    m+=1

                    # 强制 Qt 处理事件往返, 用于实时反馈日志
                    QCoreApplication.processEvents()

            # 总进度条
            if file_num > 1:
                self.root_progress_bar.setValue(int(n / len(file_num)*100))

        return "Mission Success!"


    def start_processing(self):

        path1 = self.edit_path1.text() or self.default_args[0]
        path2 = self.edit_path2.text() or self.default_args[1]
        out_type = self.edit_out_type.text() or self.default_args[2]
        subimage_size = self.edit_subimage_size.text() or self.default_args[3]
        overlap_rate = self.edit_overlap_rate.text() or self.default_args[4]

        if not path1 or not path2 or not subimage_size or not overlap_rate:
            self.text_output.append("ERROR: Please enter all the required fields.")
            return

        try:
            result = self.slice_image(path1, path2, out_type, int(subimage_size), float(overlap_rate))
            self.text_output.append(str(result)+ "\n")
        except Exception as e:
            # Display any exception that occurs during the function call
            self.text_output.append(str(e))



if __name__ == '__main__':
    default_args= [
            #"H:\\a4.code\\pythonProject\\a011_cv\\a_proj_mangrove\\data",
            #"H:\\a4.code\\pythonProject\\a011_cv\\a_proj_mangrove\\data_split_to_640",
            "input_dir",
            "output_dir",
            ".tif",
            "640",
            "0.2"
        ] 
    app = QApplication(sys.argv)
    window = ImageProcessingApp(default_args)
    window.show()
    sys.exit(app.exec_())
