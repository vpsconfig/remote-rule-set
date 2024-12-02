#!/bin/bash

# 定义仓库和目标路径
BASE_URL="http://127.0.0.1:56290/Clash"
LOCAL_DIR="./rule/Clash"

# 进入目标目录
cd "$LOCAL_DIR" || exit

download_and_check() {
    local output_file=$1
    local expected_md5=$2
    local url=$3
    local output_text_file=$4

    if wget -q --no-proxy -O "$output_file" "$url"; then
        if [ "$(md5sum "$output_file" | awk '{print $1}')" = "$expected_md5" ]; then
            rm -f "$output_file"
        else
            cp "$output_file" "$output_text_file"
        fi
    else
        echo "Error downloading $url" >&2
    fi
}

# 遍历所有 .list 文件, 转换为 .yaml 文件
find . -name "*.list" | while read -r file; do
    # 去掉前缀的 "./" 并生成对应的本地 URL
    RAW_URL="$BASE_URL/${file#./}"

    # 转换 URL 为 Base64 格式
    RAW_URL_BASE64=$(echo -n "$RAW_URL" | openssl base64 -A)

    # 生成输出文件路径. 并保持原有目录结构
    OUTPUT_FILE_DOMAIN_YAML="${file%.list}_OCD_Domain.yaml"
    OUTPUT_FILE_DOMAIN_TEXT="${file%.list}_OCD_Domain.txt"
    OUTPUT_FILE_IP_YAML="${file%.list}_OCD_IP.yaml"
    OUTPUT_FILE_IP_TEXT="${file%.list}_OCD_IP.txt"

    # 下载转换后的规则文件, 丢弃无用文件, [type=3 代表域名, type=4 代表 IP](https://github.com/tindy2013/subconverter/blob/master/README-cn.md#%E8%A7%84%E5%88%99%E8%BD%AC%E6%8D%A2)
    download_and_check "$OUTPUT_FILE_DOMAIN_YAML" "0c04407cd072968894bd80a426572b13" "http://127.0.0.1:25500/getruleset?type=3&url=$RAW_URL_BASE64" "$OUTPUT_FILE_DOMAIN_TEXT"
    download_and_check "$OUTPUT_FILE_IP_YAML" "3d6eaeec428ed84741b4045f4b85eee3" "http://127.0.0.1:25500/getruleset?type=4&url=$RAW_URL_BASE64" "$OUTPUT_FILE_IP_TEXT"

done

# 遍历所有 *_OCD_*.txt 文件, 转换为实际可用的格式和 .mrs 文件
find . -name "*_OCD_*.txt" | while read -r file; do
    # 读取文件的第一行
    first_line=$(head -n 1 "$file")
    # 检查第一行是否包含 'payload'
    if [[ "$first_line" == *"payload"* ]]; then
        # 如果包含 'payload'，则删除
        sed -i '1d' "$file"
    fi
    # 删除所有单引号、减号和空格
    sed -i "s/'//g; s/-//g; s/[[:space:]]//g" "$file"

    # 获取文件的目录路径和文件名（不包含扩展名）
    file_dir=$(dirname "$file")
    filename=$(basename "$file" .txt)
    # 判断文件名中是否包含 "Domain" 或 "IP" 来选择参数
    if [[ "$filename" == *_OCD_Domain* ]]; then
        param="domain"
    elif [[ "$filename" == *_OCD_IP* ]]; then
        param="ipcidr"
    else
        echo "未识别的文件类型: $file"
        continue
    fi
    # 设置输出的 .mrs 文件路径，使其与原文件目录一致
    output_file="$file_dir/$filename.mrs"
    # 使用 mihomo convert-ruleset 进行转换
    /usr/bin/mihomo convert-ruleset "$param" text "$file" "$output_file"
    # 输出转换状态
    if [[ $? -eq 0 ]]; then
        echo "文件 $file 转换成功为 $output_file"
    else
        echo "文件 $file 转换失败"
    fi
done
