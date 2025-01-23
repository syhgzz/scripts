
rc4() {
  local data="$1"
  local key="$2"
  local data_len="${#data}"
  local key_len="${#key}"

  local i j a b c temp
  local s

  for i in $(seq 0 255); do
    eval "s$i=$i"
  done

  j=0
  for i in $(seq 0 255); do
    j=$(( (j + $(eval echo "\$s$i") + $(printf '%d' "'${key:i % key_len:1}")) % 256 ))
    temp=$(eval echo "\$s$i")
    eval "s$i=\$s$j"
    eval "s$j=$temp"
  done

  a=0
  b=0
  encrypted_data=""
  for i in $(seq 0 $((data_len - 1))); do
    a=$(( (a + 1) % 256 ))
    b=$(( (b + $(eval echo "\$s$a")) % 256 ))
    temp=$(eval echo "\$s$a")
    eval "s$a=\$s$b"
    eval "s$b=$temp"
    c=$(( ($(eval echo "\$s$a") + $(eval echo "\$s$b")) % 256 ))
    encrypted_byte=$(( $(eval echo "\$s$c") ^ $(printf '%d' "'${data:i:1}") ))
    encrypted_data=$(printf "%s%02x" "$encrypted_data" $encrypted_byte)
  done
  echo "$encrypted_data"
}

rckey=$(date +%s%3N)
user="2240201012"
password="292519"
encrypted_password=$(rc4 "$password" "$rckey")
while true
do 
    ping -c 3 www.baidu.com > /dev/null 2>&1
    if [ $? -eq 0 ];then
    echo "Network ok"
    else
    echo "Connecting....."
		wget --quiet --post-data "opr=pwdLogin&userName=$user&pwd=$encrypted_password&auth_tag=$rckey&rememberPwd=0" --header='Connection: keep-alive' \
		  --header='Accept: */*' \
		  --header='X-Requested-With: XMLHttpRequest' \
		  --header='User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36 Edg/111.0.1661.44' \
		  --header='Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
		  --header='Origin: http://1.1.1.3' \
		  --header='Referer: http://1.1.1.3/ac_portal/20230318032256/pc.html?template=20230318032256&tabs=pwd-sms&vlanid=0&_ID_=0&switch_url=&url=http://1.1.1.3/homepage/index.html&controller_type=&mac=99-99-99-99-99-99' \
		  --header='Accept-Language: zh-CN,zh;q=0.9' \
		  --header='Accept-Encoding: gzip, deflate' \
		  'http://1.1.1.3/ac_portal/login.php' 
      
      echo "Web authentication successful"
		  
      fi
    exit 0
done
