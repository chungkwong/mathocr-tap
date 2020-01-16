# Offline handwritten mathematical expression recognition via stroke extraction and TAP

The purpose of this repository is to provide a trainable [online handwritten mathematical expression recognition system](https://github.com/JianshuZhang/TAP), which can be used with a [stroke extractor](https://github.com/chungkwong/mathocr-myscript) to do offline handwritten mathematical expression recognition.

## Usage

1. Ensure that Perl, Java, pandoc, [Theano](https://github.com/Theano/Theano) and [libgpuarray](https://github.com/Theano/libgpuarray) are installed
2. Clone this repository: `git clone 'https://github.com/chungkwong/mathocr-tap.git'`
3. Change directory: `cd mathocr-tap/work/src`
4. Train a model(optional, a pretrained model is included): `./train.sh && ./train_weightnoise.sh`
5. Test: `./test.sh`
6. Recognize your images: `./recognize.sh IMAGE_FILE IMAGE_FILE...`

## Structure

- `data`: contains compressed dataset
    - `offline.tar.xz`: rendered from CROHME 2016 and then extracted
- `work`:
    - `data`: contains dataset
        - `train`: contains the training set
        - `valid`: contains the validation set
        - `test`: contains the test set
        - `test_symlg`: contains the test set in symLG format
    - `model`: contains trained models(ensemble model is supported by placing multiple models here)
        - `NAME.npz.pkl`
        - `NAME.npz`
    - `log`: contains logs and test results
        - `DATE-TIME`
            - `log.txt`: log
            - `valid_decode_result.txt`: reognition results on the validation set
            - `test_decode_result.txt`: recognition results on the test set
            - `Results`: Test report
    - `src`: contains programs
        - `crohmelib`: contains tools for InkML format
        - `lgeval`: contains tools for evaluation
        - `convert2symLG`: contains tools for format conversion
        - `train.sh`: entrance of the training procedure(without weight noise)
        - `train_weightnoise.sh`: entrance of the training procedure(with weight noise)
        - `test.sh`: entrance of the test procedure
        - `recognize.sh`: entrance of the recognizer

## Accuracy

Here are accuracy of some offline handwritten mathematical expression recognition systems on the test set of CROHME 2016.

System|Exact|<=1 error|<= 2 errors|Structural correct|Remark
---|---|---|---|---|---
USTC, WAP|42.0%|55.1%|59.3%|-|Ensemble modeling is applied(5 models)
Stroke extractor + TAP|43.07%|56.67%|62.95%|64.95%|
TDTU, CNN-BLSTM-LSTM|45.60%|59.29%|65.65%|-|Data augmentation is applied(36.27% before data augmentation)
USTC, MSD|50.1%|63.8%|67.4%|-|Ensemble modeling is applied(5 models)

It should be noted that online accuracy of this version of TAP is 43.68%, which is close to its offline counterpart. The point is that if we have trained an online recognizer with extracted strokes, we can obtain an offline recognizer which is nearly as good as it.

## References

If you are interested in online mathematical expression recognition, you can read [Track, attend and parse (TAP): An end-to-end framework for online handwritten mathematical expression recognition](https://ieeexplore.ieee.org/abstract/document/8373726):
```
@article{zhang2018track,
  title={Track, Attend and Parse (TAP): An End-to-end Framework for Online Handwritten Mathematical Expression Recognition},
  author={Zhang, Jianshu and Du, Jun and Dai, Lirong},
  journal={IEEE Transactions on Multimedia},
  year={2018},
  publisher={IEEE}
}
```

If you are interested in stroke extraction, you can read [Stroke extraction for offline handwritten mathematical expression recognition](https://arxiv.org/abs/1905.06749):

```bibtex
@misc{1905.06749,
Author = {Chungkwong Chan},
Title = {Stroke extraction for offline handwritten mathematical expression recognition},
Year = {2019},
Eprint = {arXiv:1905.06749},
}
```

# 基于笔划提取和TAP的脱机手写数学公式识别

本仓库的目的是提供一个可训练的[联机手写数学公式识别系统](https://github.com/JianshuZhang/TAP)，配合一个[笔划提取器](https://github.com/chungkwong/mathocr-myscript)，可以用于打造一个脱机手写数学公式识别系统。

## 用法

1. 确保Perl，Java，pandoc，[Theano](https://github.com/Theano/Theano)和[libgpuarray](https://github.com/Theano/libgpuarray)已安装好
2. 克隆本仓库：`git clone 'https://github.com/chungkwong/mathocr-tap.git'`
3. 进入代码目录：`cd mathocr-tap/work/src`
4. 训练模型（可选，因为提供了预训练模型）：`./train.sh && ./train_weightnoise.sh`
5. 测试准确度：`./test.sh`
6. 识别你提供的图片：`./recognize.sh 图片 图片...`

## 文件结构

- `data`：存放压缩的数据集
    - `offline.tar.xz`是对CROHME 2016数据集作渲染再笔划提取的结果
- `work`：
    - `data`：存放已解压数据集
        - `train`：存放训练集
        - `valid`：存放检验集
        - `test`：存放测试集
        - `test_symlg`: 存放symLG格式的测试集
    - `model`：存放训练出的模型(放多个模型的话它们在测试时会聚合起来)
        - `名称.npz.pkl`
        - `名称.npz`
    - `log`：存放训练日志和测试结果
        - `开始日期-开始时间`
            - `log.txt`：训练日志
            - `valid_decode_result.txt`：检验集上结果
            - `test_decode_result.txt`：测试集上结果
            - `Results`：测试报告
    - `src`：存放程序代码
        - `crohmelib`：存放用于处理CROHME数据集中InkML文件的工具
        - `lgeval`：存放用于计算准确率的工具
        - `convert2symLG`：存放用于结果格式转换的工具
        - `train.sh`：训练程序入口（不使用权重噪声）
        - `train_weightnoise.sh`：训练程序入口（使用权重噪声）
        - `test.sh`：测试程序入口
        - `recognize.sh`: 识别器入口

## 准确度

以下是比较本系统和其它脱机手写数学公式识别系统在CROHME 2016测试集上的准确率：

系统|完全正确|至多一个错误|至多两个错误|结构正确|注记
---|---|---|---|---|---
USTC, WAP|42.0%|55.1%|59.3%|-|组合了五个模型
Stroke extractor + TAP|43.07%|56.67%|62.95%|64.95%|
TDTU, CNN-BLSTM-LSTM|45.60%|59.29%|65.65%|-|使用了扩充数据集（原数据集上为36.27%）
USTC, MSD|50.1%|63.8%|67.4%|-|组合了五个模型

值得注意的是，这版本TAP的联机识别准确率为43.68%，与脱机识别准确率相若。这表明通过用提取出的笔划去训练一个联机识别系统，可以得到一个准确度与之相当的脱机识别系统。

## 参考资料

如果你对联机手写数学公式识别系统感兴趣，请参阅[Track, attend and parse (TAP): An end-to-end framework for online handwritten mathematical expression recognition](https://ieeexplore.ieee.org/abstract/document/8373726)：	
```
@article{zhang2018track,
  title={Track, Attend and Parse (TAP): An End-to-end Framework for Online Handwritten Mathematical Expression Recognition},
  author={Zhang, Jianshu and Du, Jun and Dai, Lirong},
  journal={IEEE Transactions on Multimedia},
  year={2018},
  publisher={IEEE}
}
```

如果你对笔划提取算法感兴趣，请参阅[Stroke extraction for offline handwritten mathematical expression recognition](https://arxiv.org/abs/1905.06749):

```bibtex
@misc{1905.06749,
Author = {Chungkwong Chan},
Title = {Stroke extraction for offline handwritten mathematical expression recognition},
Year = {2019},
Eprint = {arXiv:1905.06749},
}
```
