# QBot-StartScripts
An easy way to launch MaiBot/AstrBot on Linux&Windows  

## 支持与帮助
[文档页](https://docs.meowyun.cn/info/welcome.html)

## 关键提醒
关于脚本的使用方法具体见视频部分，maibot脚本已经完成升级，现在可以使用新脚本来一站式管理MaiBot
```bash
curl -s https://dl.meowyun.cn/bot/bash/maibot.sh > maibot.sh && bash maibot.sh
```

```
MaiBot文件分布图
/path/to/your/maibot
├── Maim-with-u/
│   ├── venv/
│   │   └── bin/
│   │       ├── activate
│   │       ├── python
│   │       ├── python3
│   │       └── ...
│   ├── MaiBot/
│   │   ├── bot.py
│   │   └── ...
│   ├── MaiBot-Napcat-Adapter/
│   │   ├── main.py
│   │   └── ...
│   ├── (可选)maimbot_tts_adapter/
│   └── start.sh(下载的启动脚本)
├── 
└── ...
```

```
AstrBot文件分布图
AstrBot
├── venv/
├── data/
├── ...
└── start.sh(下载的启动脚本)
```
