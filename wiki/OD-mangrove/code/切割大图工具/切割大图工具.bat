@echo off
chcp 65001 > nul

REM 检查是否已安装 Python
conda --version >nul 2>&1
if %errorlevel% neq 0 (
	echo 系统未安装Python，将为您下载Python3.9的安装包；	
	echo 下载完成后，双击 Miniconda3-py39_4.12.0-Windows-x86_64.exe 按提示对miniconda进行安装；
	echo 注意：安装时一定要记得将miniconda的安装目录加入到系统的环境变量；
	echo 安装成功后，重新点击执行 slice_app.bat 文件。
	start /wait "" https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-py39_4.12.0-Windows-x86_64.exe
	pause
	exit
)

REM 安装依赖
call activate base
python -m pip list | find /i "PyQt5" > nul
set "pyQt5_installed=%errorlevel%"

python -m pip list | find /i "tqdm" > nul
set "tqdm_installed=%errorlevel%"

if %pyQt5_installed% neq 0 (
    python -m pip install PyQt5
)
if %tqdm_installed% neq 0 (
    python -m pip install tqdm
)

REM 执行“切割图像app"

python split_app.py
