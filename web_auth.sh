#!/bin/sh
# 城院上网脚本 curl版. 
# 来源: https://github.com/YYH2913/ZUCC_Internet_Automatic_Authrazation/tree/main By Ye Yanghan
# 有所改动, 增加了系统日志, 记录于/var/log/syslog. By Zhou Zhuo 2024.10 


#此处填城院上网的用户名和密码
user="22222222"
password="333333"

rc4() {
  local data="$1"
  local key="$2"
  local data_len=${#data}
  local key_len=${#key}

  local i j a b c temp
  j=0
  a=0
  b=0
  encrypted_data=""

  # 初始匄1�7 s 数组
  for i in $(seq 0 255); do
    eval "s$i=$i"
  done

  # KSA 算法
  for i in $(seq 0 255); do
    j=$(( (j + $(eval echo "\$s$i") + $(printf '%d' "'$(echo $key | cut -c $(($i % $key_len + 1)))")) % 256 ))
    temp=$(eval echo "\$s$i")
    eval "s$i=\$s$j"
    eval "s$j=$temp"
  done

  # PRGA 算法
  for i in $(seq 0 $(expr $data_len - 1)); do
    a=$(( (a + 1) % 256 ))
    b=$(( (b + $(eval echo "\$s$a")) % 256 ))
    temp=$(eval echo "\$s$a")
    eval "s$a=\$s$b"
    eval "s$b=$temp"
    c=$(( ($(eval echo "\$s$a") + $(eval echo "\$s$b")) % 256 ))
    encrypted_byte=$(( $(eval echo "\$s$c") ^ $(printf '%d' "'$(echo $data | cut -c $(($i + 1)))") ))
    encrypted_data=$(printf "%s%02x" "$encrypted_data" $encrypted_byte)
  done

  echo "$encrypted_data"
}

rckey=$(date +%s)  # 使用标准秒时间戳

encrypted_password=$(rc4 "$password" "$rckey")

if ping -c 1 163.com > /dev/null 2>&1; then
  logger "WEBAUTH: Network status: Online"
  exit 0
else
  
  logger "WEBAUTH: Network status: Offline."
  
  for i in $(seq 3); do
    logger "WEBAUTH: Time $i: Connecting to network."
    response=$(curl -s -X POST 'http://1.1.1.3/ac_portal/login.php' \
          -H 'Connection: keep-alive' \
          -H 'Accept: */*' \
          -H 'X-Requested-With: XMLHttpRequest' \
          -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36 Edg/111.0.1661.44' \
          -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
          -H 'Origin: http://1.1.1.3' \
          -H 'Referer: http://1.1.1.3/ac_portal/20230318032256/pc.html?template=20230318032256&tabs=pwd-sms&vlanid=0&_ID_=0&switch_url=&url=http://1.1.1.3/homepage/index.html&controller_type=&mac=99-99-99-99-99-99' \
          -H 'Accept-Language: zh-CN,zh;q=0.9' \
          -H 'Accept-Encoding: gzip, deflate' \
          --data "opr=pwdLogin&userName=$user&pwd=$encrypted_password&auth_tag=$rckey&rememberPwd=0")

    if [ $? -eq 0 ]; then
        logger "WEBAUTH: Web authentication succeeds. Network is connected."
        exit 0
    fi
      
  done
  
  logger -p user.err "WEBAUTH: Web authentication failed. Network is disconnected."
  exit 1

fi




