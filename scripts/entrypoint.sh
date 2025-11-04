#!/bin/bash

# GitHub設定を自動適用
/usr/local/bin/setup-github.sh

# 元のコマンドを実行
exec "$@"
