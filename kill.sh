#!/bin/bash

# 强制关闭skynet进程，only for debug时使用。会造成数据丢失
# 使用 ps 和 grep 命令查找符合条件的进程, 然后使用 awk 提取进程 ID，并使用 xargs 将其传递给 kill 命令
ps -ef | grep "config.main" | grep -v grep | awk '{print $2}' | xargs kill -9
