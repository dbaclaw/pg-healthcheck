#!/bin/bash

# 参考 https://github.com/digoal/pgsql_admin_script/blob/master/generate_report.sh
# 用法  ./pg_check.sh >/tmp/pg_report.log 2>&1
# 生成报告目录   grep -E "^----->>>|^\|" /tmp/pg_report.log | sed 's/^----->>>---->>>/    /' | sed '1 i\ \ 目录\n\n' | sed '$ a\ \n\n\ \ 正文\n\n'

# Check required arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 port user pgdata"
    echo "Example: $0 5000 postgres /data/pgsql5000/pgsql/data"
    exit 1
fi

# Check if PGHOME is set
if [ -z "$PGHOME" ]; then
    echo "Error: PGHOME environment variable is not set"
    exit 1
fi

# Set environment variables
export PGPORT=$1
export PGUSER=$2
export PGDATA=$3

export PGWAL=${PGDATA}/pg_wal
export pg_log_dir=${PGDATA}/log
#export PGHOST=127.0.0.1
# export PGPORT=5000
# export PGDATABASE=postgres
# PGUSER='dba'
#export PGPASSWORD=admin
# export PGDATA=/data/pgsql5000/pgsql/data
# export PGHOME=/data/pgsql5000/pgsql/14
# export PGWAL=/data/pgsql5000/pgsql/data/pg_wal
# export pg_log_dir=/data/pgsql5000/pgsql/data/log

# export PATH=$PGHOME/bin:$PATH:.
DATE1=`date +"%Y%m%d%H%M"`
# export LD_LIBRARY_PATH=$PGHOME/lib:/lib64:/usr/lib64:/usr/local/lib64:/lib:/usr/lib:/usr/local/lib:$LD_LIBRARY_PATH


# 记住当前目录
PWD=`pwd`

# 获取postgresql主版本号
pg_major_version=`cat $PGDATA/PG_VERSION`
pg_version_9x=`cat $PGDATA/PG_VERSION|grep "9."`
pg_version_96=`cat $PGDATA/PG_VERSION|grep "9.6"`


# 检查是否standby
is_standby=`psql -p $PGPORT -U $PGUSER --pset=pager=off -q -A -t -c 'select pg_is_in_recovery()'`

echo "    ----- PostgreSQL 巡检报告 -----  "
echo "    ===== $DATE1        =====  "


if [ $is_standby == 't' ]; then
echo "    ===== 这是standby节点     =====  "
else
echo "    ===== 这是primary节点     =====  "
fi
echo ""


echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|                      操作系统信息                       |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""

echo "----->>>---->>>  数据库用户信息: "
id ${PGUSER}

echo "----->>>---->>>  数据库数据目录属主信息: "
ls -ld ${PGDATA}

echo "----->>>---->>>  主机名: "
hostname -s
echo ""
echo "----->>>---->>>  以太链路信息: "
ip link show
echo ""
echo "----->>>---->>>  IP地址信息: "
ip addr show
echo ""
echo "----->>>---->>>  路由信息: "
ip route show
echo ""
echo "----->>>---->>>  操作系统内核: "
uname -a
echo ""
echo "----->>>---->>>  内存: "
free -h
echo ""
echo "----->>>---->>>  CPU: "
lscpu
echo ""
echo "----->>>---->>>  块设备: "
lsblk
echo ""
echo "----->>>---->>>  进程树: "
pstree -a -A -c -l -n -p -u -U
echo ""
echo "----->>>---->>>  PG用户进程树: "
ps f -u $PGUSER
echo ""
echo "----->>>---->>>  操作系统配置文件 静态配置信息: "
echo "----->>>---->>>  /etc/sysctl.conf "
grep "^[a-z]" /etc/sysctl.conf
# echo ""
# echo "----->>>---->>>  /etc/security/limits.conf "
# grep -v "^#" /etc/security/limits.conf|grep -v "^$"
# echo ""
# echo "----->>>---->>>  /etc/security/limits.d/*.conf "
# for dir in `ls /etc/security/limits.d`; do echo "/etc/security/limits.d/$dir : "; grep -v "^#" /etc/security/limits.d/$dir|grep -v "^$"; done 
echo -e "\n"
echo "----->>>---->>>  /etc/fstab "
cat /etc/fstab
echo ""
echo "----->>>---->>>  /etc/rc.local "
cat /etc/rc.local
echo ""
echo "----->>>---->>>  /etc/selinux/config "
cat /etc/selinux/config
# echo ""
# echo "----->>>---->>>  sysctl -a 动态配置信息: "
# sysctl -a
echo ""
echo "----->>>---->>>  mount 动态配置信息: "
mount -l
echo ""
echo "----->>>---->>>  selinux 动态配置信息: "
getsebool
sestatus
echo ""
echo "----->>>---->>>  建议禁用Transparent Huge Pages (THP): "
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag
echo ""
echo -e "\n"

echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|                       数据库信息                        |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""

echo "----->>>---->>>  数据库版本: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select version()'

echo "----->>>---->>>  数据库唯一标识: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select system_identifier from pg_control_system()'

echo "----->>>---->>>  已安装的插件: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),extname as name,extversion as version from pg_extension'
done

echo "----->>>---->>>  用户创建了多少对象: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),rolname,nspname,relkind,count(*) from pg_class a,pg_authid b,pg_namespace c where a.relnamespace=c.oid and a.relowner=b.oid and nspname !~ $$^pg_$$ and nspname<>$$information_schema$$ group by 1,2,3,4 order by 5 desc'
done

echo "----->>>---->>>  用户对象占用空间的柱状图: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),buk this_buk_no,cnt rels_in_this_buk,pg_size_pretty(min) buk_min,pg_size_pretty(max) buk_max from( select row_number() over (partition by buk order by tsize),tsize,buk,min(tsize) over (partition by buk),max(tsize) over (partition by buk),count(*) over (partition by buk) cnt from ( select pg_relation_size(a.oid) tsize, width_bucket(pg_relation_size(a.oid),tmin-1,tmax+1,10) buk from (select min(pg_relation_size(a.oid)) tmin,max(pg_relation_size(a.oid)) tmax from pg_class a,pg_namespace c where a.relnamespace=c.oid and nspname !~ $$^pg_$$ and nspname<>$$information_schema$$) t, pg_class a,pg_namespace c where a.relnamespace=c.oid and nspname !~ $$^pg_$$ and nspname<>$$information_schema$$ ) t)t where row_number=1;'
done

echo "----->>>---->>>  当前用户的操作系统定时任务: "
echo "I am `whoami`"
crontab -l
echo "建议: "
echo "    仔细检查定时任务的必要性, 以及定时任务的成功与否的评判标准, 以及监控措施. "
echo "    请以启动数据库的OS用户执行本脚本. "
echo -e "\n"


common() {
# 进入pg_log工作目录
cd $PGDATA
eval cd $pg_log_dir

echo "----->>>---->>>  获取pg_hba.conf md5值: "
md5sum $PGDATA/pg_hba.conf
echo "建议: "
echo "    主备md5值一致(判断主备配置文件是否内容一致的一种手段)."
echo -e "\n"

echo "----->>>---->>>  获取pg_hba.conf配置: "
grep '^\ *[a-z]' $PGDATA/pg_hba.conf
echo "建议: "
echo "    主备配置尽量保持一致, 注意trust和password认证方法的危害(password方法 验证时网络传输密码明文, 建议改为md5), 建议除了unix socket可以使用trust以外, 其他都使用md5或者LDAP认证方法."
echo "    建议先设置白名单(超级用户允许的来源IP, 可以访问的数据库), 再设置黑名单(不允许超级用户登陆, reject), 再设置白名单(普通应用), 参考pg_hba.conf中的描述. "
echo -e "\n"

echo "----->>>---->>>  获取postgresql.conf md5值: "
md5sum $PGDATA/postgresql.conf
echo "建议: "
echo "    主备md5值一致(判断主备配置文件是否内容一致的一种手段)."
echo -e "\n"

echo "----->>>---->>>  获取postgresql.conf配置: "
grep '^\ *[a-z]' $PGDATA/postgresql.conf|awk -F "#" '{print $1}'
echo "建议: "
echo "    主备配置尽量保持一致, 配置合理的参数值."

echo "----->>>---->>>  获取系统级自定义配置: "
grep '^\ *[a-z]' $PGDATA/postgresql.auto.conf|awk -F "#" '{print $1}'
echo "建议: "
echo "    主备配置尽量保持一致, 配置合理的参数值."

echo "----->>>---->>>  获取修改过的静态参数: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select name,setting,boot_val from pg_settings where setting!=boot_val and sourcefile is not null'


echo "----->>>---->>>  用户或数据库级别定制参数: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select t1.datname as db_name,t2.rolname as user_name,p.setconfig as config from pg_db_role_setting p left join pg_database t1 on p.setdatabase=t1.oid left join pg_roles t2 on p.setrole=t2.oid'
echo "建议: "
echo "    定制参数需要关注, 优先级高于数据库的启动参数和配置文件中的参数, 特别是排错时需要关注. "
echo -e "\n"

echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|                   数据库错误日志分析                    |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""

echo "----->>>---->>>  历史错误日志信息: "
# cat *.csv | grep -E "^[0-9]" | grep -E "ERROR|FATAL|PANIC" | awk -F "," '{print $12" , "$13" , "$14}'|sort|uniq -c|sort -rn
find . -name "*.csv" -mtime -30 -exec grep -E 'ERROR|FATAL|PANIC' {} \;|awk -F ',' '{print $12,$13,$14}'|sort |uniq -c
find . -name "*.log" -mtime -30 -exec grep -E 'ERROR|FATAL|PANIC' {} \;|awk -F ',' '{print $12,$13,$14}'|sort |uniq -c
echo "建议: "
echo "    参考 http://www.postgres.cn/docs/12/errcodes-appendix.html"
echo -e "\n"

echo "----->>>---->>>  历史连接请求情况: "
find . -name "*.csv" -type f -mtime -30 -exec grep "connection authorized" {} +|awk -F "," '{print $2,$3,$5}'|sed 's/\:[0-9]*//g'|sort|uniq -c|sort -n -r
echo "    输出格式(频次,用户,数据库,客户端地址). "
echo "建议: "
echo "    连接请求非常多时, 请考虑应用层使用连接池. "
echo -e "\n"

echo "----->>>---->>>  历史认证失败情况: "
find . -name "*.csv" -type f -mtime -30 -exec grep "password authentication failed" {} +|awk -F "," '{print $2,$3,$5}'|sed 's/\:[0-9]*//g'|sort|uniq -c|sort -n -r
echo "    输出格式(频次,用户,数据库,客户端地址). "
echo "建议: "
echo "    认证失败次数很多时, 可能是有用户在暴力破解, 建议使用auth_delay插件防止暴力破解. "
echo "    参考 http://www.postgres.cn/docs/12/auth-delay.html"
echo -e "\n"

echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|                   数据库慢SQL日志分析                   |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""


echo "----->>>---->>>  慢查询统计: "
find . -name "*.csv" -mtime -30 -exec cat {} \;|awk -F "," '{print $1" "$2" "$3" "$8" "$14}' |grep "duration:"|grep -v "plan:"|awk '{print $1" "$4" "$5" "$6}'|sort|uniq -c|sort -rn
echo "建议: "
echo "    输出格式(条数,日期,用户,数据库,QUERY,耗时ms). "
echo "    慢查询反映执行时间超过log_min_duration_statement的SQL, 可以根据实际情况分析数据库或SQL语句是否有优化空间. "
echo ""
echo "----->>>---->>>  慢查询分布头10条的执行时间, ms: "
find . -name "*.csv" -mtime -30 -exec cat {} \;|awk -F "," '{print $1" "$2" "$3" "$8" "$14}' |grep "duration:"|grep -v "plan:"|awk '{print $1" "$4" "$5" "$6" "$7" "$8}'|sort -k 6 -n|head -n 10
echo ""
echo "----->>>---->>>  慢查询分布尾10条的执行时间, ms: "
find . -name "*.csv" -mtime -30 -exec cat {} \;|awk -F "," '{print $1" "$2" "$3" "$8" "$14}' |grep "duration:"|grep -v "plan:"|awk '{print $1" "$4" "$5" "$6" "$7" "$8}'|sort -k 6 -n|tail -n 10
echo -e "\n"

echo "----->>>---->>>  auto_explain 分析统计: "
find . -name "*.csv" -mtime -30 -exec cat {} \;|awk -F "," '{print $1" "$2" "$3" "$8" "$14}' |grep "plan:"|grep "duration:"|awk '{print $1" "$4" "$5" "$6}'|sort|uniq -c|sort -rn
echo "建议: "
echo "    输出格式(条数,日期,用户,数据库,QUERY). "
echo "    慢查询反映执行时间超过auto_explain.log_min_duration的SQL, 可以根据实际情况分析数据库或SQL语句是否有优化空间, 分析csvlog中auto_explain的输出可以了解语句超时时的执行计划详情. "
echo -e "\n"

echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|                   数据库空间使用分析                    |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""

echo "----->>>---->>>  输出文件系统剩余空间: "
df -T -h
echo "建议: "
echo "    注意预留足够的空间给数据库. "
echo -e "\n"

echo "----->>>---->>>  输出表空间对应目录: "
echo $PGDATA
ls -la $PGDATA/pg_tblspc/
echo "建议: "
echo "    注意表空间如果不是软链接, 注意是否刻意所为, 正常情况下应该是软链接. "
echo -e "\n"

echo "----->>>---->>>  输出表空间使用情况: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select spcname,pg_tablespace_location(oid),pg_size_pretty(pg_tablespace_size(oid)) from pg_tablespace order by pg_tablespace_size(oid) desc'
echo "建议: "
echo "    注意检查表空间所在文件系统的剩余空间, (默认表空间在$PGDATA/base目录下). "
echo -e "\n"

echo "----->>>---->>>  输出数据库使用情况: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select datname,pg_size_pretty(pg_database_size(oid)) from pg_database order by pg_database_size(oid) desc'
echo "建议: "
echo "    注意检查数据库的大小, 是否需要清理历史数据. "
echo -e "\n"

echo "----->>>---->>>  输出数据库object分布情况: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select current_database(),buk this_buk_no,cnt rels_in_this_buk,pg_size_pretty(tsize) buk_size from( select row_number() over (partition by buk order by tsize),tsize,buk,count(*) over (partition by buk) cnt from ( select pg_relation_size(a.oid) tsize, width_bucket(pg_relation_size(a.oid),tmin-1,tmax+1,10) buk from (select min(pg_relation_size(a.oid)) tmin,max(pg_relation_size(a.oid)) tmax from pg_class a,pg_namespace c where a.relnamespace=c.oid and nspname !~ $$^pg_$$ and nspname<>$$information_schema$$) t, pg_class a,pg_namespace c where a.relnamespace=c.oid and nspname !~ $$^pg_$$ and nspname<>$$information_schema$$ ) t)t where row_number=1'
echo -e "\n"

echo "----->>>---->>>  TOP 10 size对象: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),b.nspname,c.relname,c.relkind,pg_size_pretty(pg_relation_size(c.oid)),a.seq_scan,a.seq_tup_read,a.idx_scan,a.idx_tup_fetch,a.n_tup_ins,a.n_tup_upd,a.n_tup_del,a.n_tup_hot_upd,a.n_live_tup,a.n_dead_tup from pg_stat_all_tables a, pg_class c,pg_namespace b where c.relnamespace=b.oid and c.relkind=$$r$$ and a.relid=c.oid order by pg_relation_size(c.oid) desc limit 10'
done
echo "建议: "
echo "    经验值: 单表超过8GB, 并且这个表需要频繁更新 或 删除+插入的话, 建议对表根据业务逻辑进行合理拆分后获得更好的性能, 以及便于对膨胀索引进行维护; 如果是只读的表, 建议适当结合SQL语句进行优化. "
echo -e "\n"


echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|                     数据库连接分析                      |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""

echo "----->>>---->>>  当前活跃度: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select now(),state,count(*) from pg_stat_activity group by 1,2'
echo "建议: "
echo "    如果active状态很多, 说明数据库比较繁忙. 如果idle in transaction很多, 说明业务逻辑设计可能有问题. 如果idle很多, 可能使用了连接池, 并且可能没有自动回收连接到连接池的最小连接数. "
echo -e "\n"

echo "----->>>---->>>  总剩余连接数: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select max_conn,used,res_for_super,max_conn-used-res_for_super res_for_normal from (select count(*) used from pg_stat_activity) t1,(select setting::int res_for_super from pg_settings where name=$$superuser_reserved_connections$$) t2,(select setting::int max_conn from pg_settings where name=$$max_connections$$) t3'
echo "建议: "
echo "    给超级用户和普通用户设置足够的连接, 以免不能登录数据库. "
echo -e "\n"

echo "----->>>---->>>  用户连接数限制: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select a.rolname,a.rolconnlimit,b.connects from pg_authid a,(select usename,count(*) connects from pg_stat_activity group by usename) b where a.rolname=b.usename order by b.connects desc'
echo "建议: "
echo "    给用户设置足够的连接数, alter role ... CONNECTION LIMIT . "
echo -e "\n"

echo "----->>>---->>>  数据库连接限制: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select a.datname, a.datconnlimit, b.connects from pg_database a,(select datname,count(*) connects from pg_stat_activity group by datname) b where a.datname=b.datname order by b.connects desc'
echo "建议: "
echo "    给数据库设置足够的连接数, alter database ... CONNECTION LIMIT . "
echo -e "\n"


# ===========================================================================
# [v1.2 新增] Wait Events 采样：每 5 秒 × 12 次（合计 1 分钟）
# ===========================================================================
echo "----->>>---->>>  Wait Events 1 分钟采样分布: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q <<'SQL'
DO $$
DECLARE i int;
BEGIN
  DROP TABLE IF EXISTS _tmp_we;
  CREATE TEMP TABLE _tmp_we (wait_event_type text, wait_event text);
  FOR i IN 1..12 LOOP
    INSERT INTO _tmp_we
    SELECT wait_event_type, wait_event
      FROM pg_stat_activity
     WHERE pid <> pg_backend_pid()
       AND state <> 'idle';
    PERFORM pg_sleep(5);
  END LOOP;
END$$;
SELECT coalesce(wait_event_type,'CPU/Running') AS wait_event_type,
       coalesce(wait_event,'-')                AS wait_event,
       count(*)                                 AS samples
FROM _tmp_we
GROUP BY 1,2 ORDER BY samples DESC LIMIT 30;
SQL
echo "建议: "
echo "    wait_event_type=Client/IO/Lock/LWLock 各代表不同瓶颈类型："
echo "    Client → 应用慢响应或网络; IO → 块设备/WAL 写; Lock → 业务锁竞争; LWLock → buffer/wal 内部锁。"
echo -e "\n"


# ===========================================================================
# [v1.2 新增] Vacuum 健康度 / 进度
# ===========================================================================
echo "----->>>---->>>  Vacuum 健康度 - 死元组比例 TOP 30: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -q -A -t -c "select datname from pg_database where datistemplate=false and datname not in ('rdsdb')"` ; do
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -d $db -c "
SELECT current_database(), schemaname, relname,
       n_live_tup, n_dead_tup,
       round(n_dead_tup * 100.0 / nullif(n_live_tup,0), 2) AS dead_pct,
       last_autovacuum, autovacuum_count,
       last_autoanalyze, autoanalyze_count
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000 OR (n_live_tup > 0 AND n_dead_tup * 100.0 / n_live_tup > 10)
ORDER BY n_dead_tup DESC LIMIT 30;
"
done
echo "建议: "
echo "    dead_pct > 20% 提示 autovacuum 跟不上, last_autovacuum 长时间为空表示 autovacuum 从未运行过该表."
echo "    可针对单库降低 autovacuum_vacuum_scale_factor 或对单表 ALTER TABLE ... SET (autovacuum_vacuum_scale_factor=0.05)."
echo -e "\n"

echo "----->>>---->>>  当前正在跑的 Vacuum 进度: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c '
SELECT pid, datname, relid::regclass AS table_name, phase,
       heap_blks_total, heap_blks_scanned, heap_blks_vacuumed,
       round(heap_blks_scanned*100.0/nullif(heap_blks_total,0),2) AS scan_pct,
       index_vacuum_count
FROM pg_stat_progress_vacuum;'
echo "建议: "
echo "    phase=vacuuming heap 表示扫描中, phase=cleaning up indexes 表示在清理索引."
echo -e "\n"


# ===========================================================================
# [v1.2 新增] SSL/TLS 与 password_encryption
# ===========================================================================
echo "----->>>---->>>  SSL/TLS 与密码加密配置: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c "
SELECT name, setting, source
  FROM pg_settings
 WHERE name IN ('ssl','ssl_cert_file','ssl_key_file','ssl_ca_file',
                'ssl_prefer_server_ciphers','password_encryption')
 ORDER BY name;"
echo "----->>>---->>>  当前 SSL 在用连接 TOP 5: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c "
SELECT pid, ssl, version, cipher, bits, client_serial
  FROM pg_stat_ssl
 WHERE pid <> pg_backend_pid() LIMIT 5;"
echo "建议: "
echo "    生产环境建议 ssl=on, password_encryption=scram-sha-256."
echo "    若 pg_stat_ssl 显示 ssl=f 的连接占比高, 说明应用侧未启用 TLS 连接."
echo -e "\n"


# ===========================================================================
# [v1.2 新增] WAL 速率窗口语义：同时输出 pg_postmaster_start_time 与 stats_reset
# ===========================================================================
echo "----->>>---->>>  WAL 速率统计窗口说明: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c "
SELECT pg_postmaster_start_time()                            AS pg_started,
       (SELECT stats_reset FROM pg_stat_archiver)            AS archiver_stats_reset,
       greatest(pg_postmaster_start_time(),
                (SELECT stats_reset FROM pg_stat_archiver))  AS effective_window_start,
       now()                                                 AS now;"
echo "建议: "
echo "    WAL 速率应以 effective_window_start → now 为分母, 避免 stats_reset 截短导致虚高."
echo -e "\n"


echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|                     数据库性能分析                      |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""

echo "----->>>---->>>  TOP 5 SQL : total_cpu_time "
psql -p $PGPORT -U $PGUSER -d rdsdb --pset=pager=off -q -x -c 'select c.rolname,b.datname,a.total_exec_time/a.calls per_call_time,a.* from pg_stat_statements a,pg_database b,pg_authid c where a.userid=c.oid and a.dbid=b.oid order by a.total_exec_time desc limit 5'
echo "建议: "
echo "    检查SQL是否有优化空间, 配合auto_explain插件在csvlog中观察LONG SQL的执行计划是否正确. "
echo -e "\n"

echo "----->>>---->>>  索引数超过4并且SIZE大于10MB的表: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(), t2.nspname, t1.relname, pg_size_pretty(pg_relation_size(t1.oid)), t3.idx_cnt from pg_class t1, pg_namespace t2, (select indrelid,count(*) idx_cnt from pg_index group by 1 having count(*)>4) t3 where t1.oid=t3.indrelid and t1.relnamespace=t2.oid and pg_relation_size(t1.oid)/1024/1024.0>10 order by t3.idx_cnt desc'
done
echo "建议: "
echo "    索引数量太多, 影响表的增删改性能, 建议检查是否有不需要的索引. "
echo -e "\n"

echo "----->>>---->>>  上次巡检以来未使用或使用较少的索引: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),t2.schemaname,t2.relname,t2.indexrelname,t2.idx_scan,t2.idx_tup_read,t2.idx_tup_fetch,pg_size_pretty(pg_relation_size(indexrelid)) from pg_stat_all_tables t1,pg_stat_all_indexes t2 where t1.relid=t2.relid and t2.idx_scan<10 and t2.schemaname not in ($$pg_toast$$,$$pg_catalog$$) and indexrelid not in (select conindid from pg_constraint where contype in ($$p$$,$$u$$,$$f$$)) and pg_relation_size(indexrelid)>65536 order by pg_relation_size(indexrelid) desc'
done
echo "建议: "
echo "    建议和应用开发人员确认后, 删除不需要的索引. "
echo -e "\n"

echo "----->>>---->>>  无效索引: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -x -c 'select indexrelid,indrelid from pg_index where indisvalid=$$f$$'
echo "建议: "
echo "    创建失败的索引会形成无效索引，对执行计划及数据库膨胀均有影响，检查无效的索引后进行删除。 "
echo -e "\n"

echo "----->>>---->>>  重复索引: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -x -c "SELECT relname,(array_agg(idx))[1] idx1,pg_get_indexdef((array_agg(idx))[1]) idx1_def,(array_agg(idx))[2] idx2,pg_get_indexdef((array_agg(idx))[2]) idx2_def,(array_agg(idx))[3] idx3,pg_get_indexdef((array_agg(idx))[3]) idx3_def FROM (SELECT indrelid::regclass AS relname,indexrelid::regclass AS idx,(indrelid::text || indclass::text || indkey::text || COALESCE(indexprs::text, '') || COALESCE(indpred::text, '')) AS KEY FROM pg_index) sub GROUP BY relname, KEY HAVING count(*) > 1"
echo "建议: "
echo "    对表相同列创建重复索引会引起DML操作性能降低，删除重复索引不仅能提高性能而且也可以给数据库瘦身。 "
echo -e "\n"


echo "----->>>---->>>  数据库统计信息, 回滚比例, 命中比例, 数据块读写时间, 死锁, 复制冲突: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select datname,round(100*(xact_rollback::numeric/(case when xact_commit > 0 then xact_commit else 1 end + xact_rollback)),2)||$$ %$$ rollback_ratio, round(100*(blks_hit::numeric/(case when blks_read>0 then blks_read else 1 end + blks_hit)),2)||$$ %$$ hit_ratio, blk_read_time, blk_write_time, conflicts, deadlocks from pg_stat_database'
echo "建议: "
echo "    回滚比例大说明业务逻辑可能有问题, 命中率小说明shared_buffer要加大, 数据块读写时间长说明块设备的IO性能要提升, 死锁次数多说明业务逻辑有问题, 复制冲突次数多说明备库可能在跑LONG SQL. "
echo -e "\n"

echo "----->>>---->>>  检查点, bgwriter 统计信息: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -x -c 'select * from pg_stat_bgwriter'
echo "建议: "
echo "    checkpoint_write_time多说明检查点持续时间长, 检查点过程中产生了较多的脏页. "
echo "    checkpoint_sync_time代表检查点开始时的shared buffer中的脏页被同步到磁盘的时间, 如果时间过长, 并且数据库在检查点时性能较差, 考虑一下提升块设备的IOPS能力. "
echo "    buffers_backend_fsync太多说明需要加大shared buffer 或者 减小bgwriter_delay参数. "
echo -e "\n"


echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|                     数据库垃圾分析                      |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""

echo "----->>>---->>>  表膨胀检查: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -x -c 'SELECT
  current_database() AS db, schemaname, tablename, reltuples::bigint AS tups, relpages::bigint AS pages, otta,
  ROUND(CASE WHEN otta=0 OR sml.relpages=0 OR sml.relpages=otta THEN 0.0 ELSE sml.relpages/otta::numeric END,1) AS tbloat,
  CASE WHEN relpages < otta THEN 0 ELSE relpages::bigint - otta END AS wastedpages,
  CASE WHEN relpages < otta THEN 0 ELSE bs*(sml.relpages-otta)::bigint END AS wastedbytes,
  CASE WHEN relpages < otta THEN $$0 bytes$$::text ELSE (bs*(relpages-otta))::bigint || $$ bytes$$ END AS wastedsize,
  iname, ituples::bigint AS itups, ipages::bigint AS ipages, iotta,
  ROUND(CASE WHEN iotta=0 OR ipages=0 OR ipages=iotta THEN 0.0 ELSE ipages/iotta::numeric END,1) AS ibloat,
  CASE WHEN ipages < iotta THEN 0 ELSE ipages::bigint - iotta END AS wastedipages,
  CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta) END AS wastedibytes,
  CASE WHEN ipages < iotta THEN $$0 bytes$$ ELSE (bs*(ipages-iotta))::bigint || $$ bytes$$ END AS wastedisize,
  CASE WHEN relpages < otta THEN
    CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta::bigint) END
    ELSE CASE WHEN ipages < iotta THEN bs*(relpages-otta::bigint)
      ELSE bs*(relpages-otta::bigint + ipages-iotta::bigint) END
  END AS totalwastedbytes
FROM (
  SELECT
    nn.nspname AS schemaname,
    cc.relname AS tablename,
    COALESCE(cc.reltuples,0) AS reltuples,
    COALESCE(cc.relpages,0) AS relpages,
    COALESCE(bs,0) AS bs,
    COALESCE(CEIL((cc.reltuples*((datahdr+ma-
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)),0) AS otta,
    COALESCE(c2.relname,$$?$$) AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta -- very rough approximation, assumes all cols
  FROM
     pg_class cc
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname <> $$information_schema$$
  LEFT JOIN
  (
    SELECT
      ma,bs,foo.nspname,foo.relname,
      (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
      (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
    FROM (
      SELECT
        ns.nspname, tbl.relname, hdr, ma, bs,
        SUM((1-coalesce(null_frac,0))*coalesce(avg_width, 2048)) AS datawidth,
        MAX(coalesce(null_frac,0)) AS maxfracsum,
        hdr+(
          SELECT 1+count(*)/8
          FROM pg_stats s2
          WHERE null_frac<>0 AND s2.schemaname = ns.nspname AND s2.tablename = tbl.relname
        ) AS nullhdr
      FROM pg_attribute att 
      JOIN pg_class tbl ON att.attrelid = tbl.oid
      JOIN pg_namespace ns ON ns.oid = tbl.relnamespace 
      LEFT JOIN pg_stats s ON s.schemaname=ns.nspname
      AND s.tablename = tbl.relname
      AND s.inherited=false
      AND s.attname=att.attname,
      (
        SELECT
          (SELECT current_setting($$block_size$$)::numeric) AS bs,
            CASE WHEN SUBSTRING(SPLIT_PART(v, $$ $$, 2) FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$)
              IN ($$8.0$$,$$8.1$$,$$8.2$$) THEN 27 ELSE 23 END AS hdr,
          CASE WHEN v ~ $$mingw32$$ OR v ~ $$64-bit$$ THEN 8 ELSE 4 END AS ma
        FROM (SELECT version() AS v) AS foo
      ) AS constants
      WHERE att.attnum > 0 AND tbl.relkind=$$r$$
      GROUP BY 1,2,3,4,5
    ) AS foo
  ) AS rs
  ON cc.relname = rs.relname AND nn.nspname = rs.nspname
  LEFT JOIN pg_index i ON indrelid = cc.oid
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid
) AS sml order by wastedbytes desc limit 5'
done
echo "建议: "
echo "    根据浪费的字节数, 设置合适的autovacuum_vacuum_scale_factor, 大表如果频繁的有更新或删除和插入操作, 建议设置较小的autovacuum_vacuum_scale_factor来降低浪费空间. "
echo "    同时还需要打开autovacuum, 根据服务器的内存大小, CPU核数, 设置足够大的autovacuum_work_mem 或 autovacuum_max_workers 或 maintenance_work_mem, 以及足够小的 autovacuum_naptime . "
echo "    同时还需要分析是否对大数据库使用了逻辑备份pg_dump, 系统中是否经常有长SQL, 长事务. 这些都有可能导致膨胀. "
echo "    使用pg_reorg或者vacuum full可以回收膨胀的空间. "
echo "    tbloat表膨胀倍数, ibloat索引膨胀倍数, wastedpages表浪费了多少个数据块, wastedipages索引浪费了多少个数据块; "
echo "    wastedbytes表浪费了多少字节, wastedibytes索引浪费了多少字节; "
echo -e "\n"


echo "----->>>---->>>  索引膨胀检查: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -x -c 'SELECT
  current_database() AS db, schemaname, tablename, reltuples::bigint AS tups, relpages::bigint AS pages, otta,
  ROUND(CASE WHEN otta=0 OR sml.relpages=0 OR sml.relpages=otta THEN 0.0 ELSE sml.relpages/otta::numeric END,1) AS tbloat,
  CASE WHEN relpages < otta THEN 0 ELSE relpages::bigint - otta END AS wastedpages,
  CASE WHEN relpages < otta THEN 0 ELSE bs*(sml.relpages-otta)::bigint END AS wastedbytes,
  CASE WHEN relpages < otta THEN $$0 bytes$$::text ELSE (bs*(relpages-otta))::bigint || $$ bytes$$ END AS wastedsize,
  iname, ituples::bigint AS itups, ipages::bigint AS ipages, iotta,
  ROUND(CASE WHEN iotta=0 OR ipages=0 OR ipages=iotta THEN 0.0 ELSE ipages/iotta::numeric END,1) AS ibloat,
  CASE WHEN ipages < iotta THEN 0 ELSE ipages::bigint - iotta END AS wastedipages,
  CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta) END AS wastedibytes,
  CASE WHEN ipages < iotta THEN $$0 bytes$$ ELSE (bs*(ipages-iotta))::bigint || $$ bytes$$ END AS wastedisize,
  CASE WHEN relpages < otta THEN
    CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta::bigint) END
    ELSE CASE WHEN ipages < iotta THEN bs*(relpages-otta::bigint)
      ELSE bs*(relpages-otta::bigint + ipages-iotta::bigint) END
  END AS totalwastedbytes
FROM (
  SELECT
    nn.nspname AS schemaname,
    cc.relname AS tablename,
    COALESCE(cc.reltuples,0) AS reltuples,
    COALESCE(cc.relpages,0) AS relpages,
    COALESCE(bs,0) AS bs,
    COALESCE(CEIL((cc.reltuples*((datahdr+ma-
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)),0) AS otta,
    COALESCE(c2.relname,$$?$$) AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta -- very rough approximation, assumes all cols
  FROM
     pg_class cc
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname <> $$information_schema$$
  LEFT JOIN
  (
    SELECT
      ma,bs,foo.nspname,foo.relname,
      (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
      (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
    FROM (
      SELECT
        ns.nspname, tbl.relname, hdr, ma, bs,
        SUM((1-coalesce(null_frac,0))*coalesce(avg_width, 2048)) AS datawidth,
        MAX(coalesce(null_frac,0)) AS maxfracsum,
        hdr+(
          SELECT 1+count(*)/8
          FROM pg_stats s2
          WHERE null_frac<>0 AND s2.schemaname = ns.nspname AND s2.tablename = tbl.relname
        ) AS nullhdr
      FROM pg_attribute att 
      JOIN pg_class tbl ON att.attrelid = tbl.oid
      JOIN pg_namespace ns ON ns.oid = tbl.relnamespace 
      LEFT JOIN pg_stats s ON s.schemaname=ns.nspname
      AND s.tablename = tbl.relname
      AND s.inherited=false
      AND s.attname=att.attname,
      (
        SELECT
          (SELECT current_setting($$block_size$$)::numeric) AS bs,
            CASE WHEN SUBSTRING(SPLIT_PART(v, $$ $$, 2) FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$)
              IN ($$8.0$$,$$8.1$$,$$8.2$$) THEN 27 ELSE 23 END AS hdr,
          CASE WHEN v ~ $$mingw32$$ OR v ~ $$64-bit$$ THEN 8 ELSE 4 END AS ma
        FROM (SELECT version() AS v) AS foo
      ) AS constants
      WHERE att.attnum > 0 AND tbl.relkind=$$r$$
      GROUP BY 1,2,3,4,5
    ) AS foo
  ) AS rs
  ON cc.relname = rs.relname AND nn.nspname = rs.nspname
  LEFT JOIN pg_index i ON indrelid = cc.oid
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid
) AS sml order by wastedibytes desc limit 5'
done
echo "建议: "
echo "    如果索引膨胀太大, 会影响性能, 建议重建索引, create index CONCURRENTLY ... . "
echo -e "\n"

echo "----->>>---->>>  垃圾数据: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),schemaname,relname,n_dead_tup from pg_stat_all_tables where n_live_tup>0 and n_dead_tup/n_live_tup>0.2 and schemaname not in ($$pg_toast$$,$$pg_catalog$$) order by n_dead_tup desc limit 5'
done
echo "建议: "
echo "    通常垃圾过多, 可能是因为无法回收垃圾, 或者回收垃圾的进程繁忙或没有及时唤醒, 或者没有开启autovacuum, 或在短时间内产生了大量的垃圾 . "
echo "    可以等待autovacuum进行处理, 或者手工执行vacuum table . "
echo -e "\n"

echo "----->>>---->>>  大对象: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c '\lo_list'
echo ""
done
echo "建议: "
echo "    如果大对象没有被引用时, 建议删除, 否则就类似于内存泄露, 使用vacuumlo可以删除未被引用的大对象, 例如: vacuumlo -l 1000 $db -w . "
echo "    应用开发时, 注意及时删除不需要使用的大对象, 使用lo_unlink 或 驱动对应的API . "
echo "    参考 http://www.postgresql.org/docs/12/static/largeobjects.html "
echo -e "\n"


echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|                     数据库年龄分析                      |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""

echo "----->>>---->>>  数据库年龄: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select datname,age(datfrozenxid),2^31-age(datfrozenxid) age_remain from pg_database order by age(datfrozenxid) desc'
echo "建议: "
echo "    数据库的年龄正常情况下应该小于vacuum_freeze_table_age, 如果剩余年龄小于5亿, 建议人为干预, 将LONG SQL或事务杀掉后, 执行vacuum freeze . "
echo -e "\n"

echo "----->>>---->>>  表年龄: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),rolname,nspname,relkind,relname,age(relfrozenxid),2^31-age(relfrozenxid) age_remain from pg_authid t1 join pg_class t2 on t1.oid=t2.relowner join pg_namespace t3 on t2.relnamespace=t3.oid where t2.relkind in ($$t$$,$$r$$) order by age(relfrozenxid) desc limit 5'
done
echo "建议: "
echo "    表的年龄正常情况下应该小于vacuum_freeze_table_age, 如果剩余年龄小于5亿, 建议人为干预, 将LONG SQL或事务杀掉后, 执行vacuum freeze . "
echo -e "\n"

echo "----->>>---->>>  长事务, 2PC: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -x -c 'select datname,usename,query,xact_start,now()-xact_start xact_duration,query_start,now()-query_start query_duration,state from pg_stat_activity where state<>$$idle$$ and (backend_xid is not null or backend_xmin is not null) and now()-xact_start > interval $$30 min$$ order by xact_start'
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -x -c 'select name,statement,prepare_time,now()-prepare_time,parameter_types,from_sql from pg_prepared_statements where now()-prepare_time > interval $$30 min$$ order by prepare_time'
echo "建议: "
echo "    长事务过程中产生的垃圾, 无法回收, 建议不要在数据库中运行LONG SQL, 或者错开DML高峰时间去运行LONG SQL. 2PC事务一定要记得尽快结束掉, 否则可能会导致数据库膨胀. "
echo -e "\n"


echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|               数据库WAL, 流复制状态分析                |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""

echo "----->>>---->>>  是否开启归档, 自动垃圾回收: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select name,setting from pg_settings where name in ($$archive_mode$$,$$autovacuum$$,$$archive_command$$)'
echo "建议: "
echo "    建议开启自动垃圾回收, 开启归档. "
echo -e "\n"

echo "----->>>---->>>  是否有ready状态未归档文件: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select pg_ls_archive_statusdir()'
echo -e "\n"

echo "----->>>---->>>  归档统计信息: "
if [[ "$pg_version_9x" != "" ]]; then
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select pg_xlogfile_name(pg_current_xlog_location()) now_xlog, * from pg_stat_archiver'
else
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select pg_walfile_name(pg_current_wal_lsn()) now_wal, * from pg_stat_archiver'
fi
echo "建议: "
echo "    如果当前的wal文件和最后一个归档失败的wal文件之间相差很多个文件, 建议尽快排查归档失败的原因, 以便修复, 否则pg_wal目录可能会撑爆. "
echo -e "\n"

echo "----->>>---->>>  流复制统计信息: "
if [[ "$pg_version_9x" != "" ]]; then


    if [ $is_standby == 't' ]; then
        psql -p $PGPORT -U $PGUSER --pset=pager=off -q -x -c 'select pg_size_pretty(pg_wal_lsn_diff(latest_end_lsn , received_lsn)) from pg_stat_wal_receiver'
    else
        psql -p $PGPORT -U $PGUSER --pset=pager=off -q -x -c 'select pg_xlog_location_diff(pg_current_xlog_location(),flush_location), * from pg_stat_replication'
    fi

else
    if [ $is_standby == 't' ]; then
        psql -p $PGPORT -U $PGUSER --pset=pager=off -q -x -c 'select pg_size_pretty(pg_wal_lsn_diff(latest_end_lsn , received_lsn)) from pg_stat_wal_receiver'
    else
        psql -p $PGPORT -U $PGUSER --pset=pager=off -q -x -c 'select pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(),flush_lsn)), * from pg_stat_replication'
    fi
fi
echo "建议: "
echo "    关注流复制的延迟, 如果延迟非常大, 建议排查网络带宽, 以及本地读wal的性能, 远程写wal的性能. "
echo -e "\n"

echo "----->>>---->>>  流复制槽: "
if [[ "$pg_version_9x" != "" ]]; then
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select pg_xlog_location_diff(pg_current_xlog_location(),restart_lsn), * from pg_replication_slots'
else
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select pg_wal_lsn_diff(pg_current_wal_lsn(),restart_lsn), * from pg_replication_slots'
fi
echo "建议: "
echo "    如果restart_lsn和当前wal相差非常大的字节数, 需要排查slot的订阅者是否能正常接收wal, 或者订阅者是否正常. 长时间不将slot的数据取走, pg_wal目录可能会撑爆. "
echo -e "\n"


echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|                数据库安全或潜在风险分析                 |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""
echo "----->>>---->>>  密码泄露检查: "
echo "    检查 ~/.psql_history :  "
grep -i "password" ~/.psql_history|grep -i -E "role|group|user"
echo ""
if [ $pg_major_version != '12' ]; then
echo "" 
echo "    检查 $PGDATA/recovery.* :  "
grep -i "password" $PGDATA/recovery.*
else
:
fi

echo ""
echo "    检查 pg_stat_statements :  "
psql -p $PGPORT -U $PGUSER -d rdsdb --pset=pager=off -c 'select query from pg_stat_statements where (query ~* $$group$$ or query ~* $$user$$ or query ~* $$role$$) and query ~* $$password$$'
echo "    检查 pg_authid :  "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select * from pg_authid where rolpassword !~ $$^md5$$ or length(rolpassword)<>35'
echo "    检查 pg_user_mappings, pg_views :  "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -c 'select current_database(),* from pg_user_mappings where umoptions::text ~* $$password$$'
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -c 'select current_database(),* from pg_views where definition ~* $$password$$ and definition ~* $$dblink$$'
done
echo "建议: "
echo "    如果以上输出显示密码已泄露, 尽快修改, 并通过参数避免密码又被记录到以上文件中(psql -p $PGPORT -U $PGUSER -n) (set log_statement='none'; set log_min_duration_statement=-1; set log_duration=off; set pg_stat_statements.track_utility=off;) . "
echo "    明文密码不安全, 建议使用create|alter role ... encrypted password. "
echo "    在fdw, dblink based view中不建议使用密码明文. "
echo "    在recovery.*的配置中不要使用密码, 不安全, 可以使用.pgpass配置密码 . "
echo -e "\n"

echo "----->>>---->>>  用户密码到期时间: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select rolname,rolvaliduntil from pg_authid order by rolvaliduntil'
echo "建议: "
echo "    到期后, 用户将无法登陆, 记得修改密码, 同时将密码到期时间延长到某个时间或无限时间, alter role ... VALID UNTIL 'timestamp' . "
echo -e "\n"

echo "----->>>---->>>  普通用户对象上的规则安全检查: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -c 'select current_database(),a.schemaname,a.tablename,a.rulename,a.definition from pg_rules a,pg_namespace b,pg_class c,pg_authid d where a.schemaname=b.nspname and a.tablename=c.relname and d.oid=c.relowner and not d.rolsuper union all select current_database(),a.schemaname,a.viewname,a.viewowner,a.definition from pg_views a,pg_namespace b,pg_class c,pg_authid d where a.schemaname=b.nspname and a.viewname=c.relname and d.oid=c.relowner and not d.rolsuper'
done
echo "建议: "
echo "    防止普通用户在规则中设陷阱, 注意有危险的security invoker的函数调用, 超级用户可能因为规则触发后误调用这些危险函数(以invoker角色). "
echo -e "\n"

echo "----->>>---->>>  普通用户自定义函数安全检查: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -c 'select current_database(),b.rolname,c.nspname,a.proname from pg_proc a,pg_authid b,pg_namespace c where a.proowner=b.oid and a.pronamespace=c.oid and not b.rolsuper and not a.prosecdef'
done
echo "建议: "
echo "    防止普通用户在函数中设陷阱, 注意有危险的security invoker的函数调用, 超级用户可能因为触发器触发后误调用这些危险函数(以invoker角色). "
echo -e "\n"

echo "----->>>---->>>  unlogged table: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),t3.rolname,t2.nspname,t1.relname from pg_class t1,pg_namespace t2,pg_authid t3 where t1.relnamespace=t2.oid and t1.relowner=t3.oid and t1.relpersistence=$$u$$'
done
echo "建议: "
echo "    unlogged table不记录wal, 无法使用流复制的方式复制到standby节点, 如果在standby节点执行某些SQL, 可能导致报错或查不到数据. "
echo "    在数据库CRASH后无法修复unlogged table, 不建议使用. "
echo "    PITR对unlogged table也不起作用. "
echo -e "\n"

echo "----->>>---->>>  剩余可使用次数不足1000万次的序列检查: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off <<EOF
select sequenceowner,schemaname,sequencename,
(max_value-last_value)/increment_by as v_times_remain
 from pg_sequences 
 where not cycle
 and (max_value-last_value)/increment_by is not null 
 and (max_value-last_value)/increment_by < 10240000 
 order by v_times_remain limit 10;
EOF
done
echo "建议: "
echo "    序列剩余使用次数到了之后, 将无法使用, 报错, 请开发人员关注. "
echo -e "\n"

echo "----->>>---->>>  触发器, 事件触发器: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),relname,tgname,proname,tgenabled from pg_trigger t1,pg_class t2,pg_proc t3 where t1.tgfoid=t3.oid and t1.tgrelid=t2.oid'
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),rolname,proname,evtname,evtevent,evtenabled,evttags from pg_event_trigger t1,pg_proc t2,pg_authid t3 where t1.evtfoid=t2.oid and t1.evtowner=t3.oid'
done
echo "建议: "
echo "    请管理员注意触发器和事件触发器的必要性. "
echo -e "\n"

echo "----->>>---->>>  检查是否使用了a-z 0-9 _ 以外的字母作为对象名: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -c 'select distinct datname from (select datname,regexp_split_to_table(datname,$$$$) word from pg_database) t where (not (ascii(word) >=97 and ascii(word) <=122)) and (not (ascii(word) >=48 and ascii(word) <=57)) and ascii(word)<>95'
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),relname,relkind from (select relname,relkind,regexp_split_to_table(relname,$$$$) word from pg_class) t where (not (ascii(word) >=97 and ascii(word) <=122)) and (not (ascii(word) >=48 and ascii(word) <=57)) and ascii(word)<>95 group by 1,2,3'
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(), typname from (select typname,regexp_split_to_table(typname,$$$$) word from pg_type) t where (not (ascii(word) >=97 and ascii(word) <=122)) and (not (ascii(word) >=48 and ascii(word) <=57)) and ascii(word)<>95 group by 1,2'
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(), proname from (select proname,regexp_split_to_table(proname,$$$$) word from pg_proc where proname !~ $$^RI_FKey_$$) t where (not (ascii(word) >=97 and ascii(word) <=122)) and (not (ascii(word) >=48 and ascii(word) <=57)) and ascii(word)<>95 group by 1,2'
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select current_database(),nspname,relname,attname from (select nspname,relname,attname,regexp_split_to_table(attname,$$$$) word from pg_class a,pg_attribute b,pg_namespace c where a.oid=b.attrelid and a.relnamespace=c.oid ) t where (not (ascii(word) >=97 and ascii(word) <=122)) and (not (ascii(word) >=48 and ascii(word) <=57)) and ascii(word)<>95 group by 1,2,3,4'
done
echo "建议: "
echo "    建议任何identify都只使用 a-z, 0-9, _ (例如表名, 列名, 视图名, 函数名, 类型名, 数据库名, schema名, 物化视图名等等). "
echo "    http://www.postgres.cn/docs/12/sql-keywords-appendix.html"
echo "    http://www.postgres.cn/docs/12/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS"
echo -e "\n"

echo "----->>>---->>>  锁等待: "
psql -p $PGPORT -U $PGUSER -x --pset=pager=off <<EOF
with    
t_wait as    
(    
  select a.mode,a.locktype,a.database,a.relation,a.page,a.tuple,a.classid,a.granted,   
  a.objid,a.objsubid,a.pid,a.virtualtransaction,a.virtualxid,a.transactionid,a.fastpath,    
  b.state,b.query,b.xact_start,b.query_start,b.usename,b.datname,b.client_addr,b.client_port,b.application_name   
    from pg_locks a,pg_stat_activity b where a.pid=b.pid and not a.granted   
),   
t_run as   
(   
  select a.mode,a.locktype,a.database,a.relation,a.page,a.tuple,a.classid,a.granted,   
  a.objid,a.objsubid,a.pid,a.virtualtransaction,a.virtualxid,a.transactionid,a.fastpath,   
  b.state,b.query,b.xact_start,b.query_start,b.usename,b.datname,b.client_addr,b.client_port,b.application_name   
    from pg_locks a,pg_stat_activity b where a.pid=b.pid and a.granted   
),   
t_overlap as   
(   
  select r.* from t_wait w join t_run r on   
  (   
    r.locktype is not distinct from w.locktype and   
    r.database is not distinct from w.database and   
    r.relation is not distinct from w.relation and   
    r.page is not distinct from w.page and   
    r.tuple is not distinct from w.tuple and   
    r.virtualxid is not distinct from w.virtualxid and   
    r.transactionid is not distinct from w.transactionid and   
    r.classid is not distinct from w.classid and   
    r.objid is not distinct from w.objid and   
    r.objsubid is not distinct from w.objsubid and   
    r.pid <> w.pid   
  )    
),    
t_unionall as    
(    
  select r.* from t_overlap r    
  union all    
  select w.* from t_wait w    
)    
select locktype,datname,relation::regclass,page,tuple,virtualxid,transactionid::text,classid::regclass,objid,objsubid,   
string_agg(   
'Pid: '||case when pid is null then 'NULL' else pid::text end||chr(10)||   
'Lock_Granted: '||case when granted is null then 'NULL' else granted::text end||' , Mode: '||case when mode is null then 'NULL' else mode::text end||' , FastPath: '||case when fastpath is null then 'NULL' else fastpath::text end||' , VirtualTransaction: '||case when virtualtransaction is null then 'NULL' else virtualtransaction::text end||' , Session_State: '||case when state is null then 'NULL' else state::text end||chr(10)||   
'Username: '||case when usename is null then 'NULL' else usename::text end||' , Database: '||case when datname is null then 'NULL' else datname::text end||' , Client_Addr: '||case when client_addr is null then 'NULL' else client_addr::text end||' , Client_Port: '||case when client_port is null then 'NULL' else client_port::text end||' , Application_Name: '||case when application_name is null then 'NULL' else application_name::text end||chr(10)||    
'Xact_Start: '||case when xact_start is null then 'NULL' else xact_start::text end||' , Query_Start: '||case when query_start is null then 'NULL' else query_start::text end||' , Xact_Elapse: '||case when (now()-xact_start) is null then 'NULL' else (now()-xact_start)::text end||' , Query_Elapse: '||case when (now()-query_start) is null then 'NULL' else (now()-query_start)::text end||chr(10)||    
'SQL (Current SQL in Transaction): '||chr(10)||  
case when query is null then 'NULL' else query::text end,    
chr(10)||'--------'||chr(10)    
order by    
  (  case mode    
    when 'INVALID' then 0   
    when 'AccessShareLock' then 1   
    when 'RowShareLock' then 2   
    when 'RowExclusiveLock' then 3   
    when 'ShareUpdateExclusiveLock' then 4   
    when 'ShareLock' then 5   
    when 'ShareRowExclusiveLock' then 6   
    when 'ExclusiveLock' then 7   
    when 'AccessExclusiveLock' then 8   
    else 0   
  end  ) desc,   
  (case when granted then 0 else 1 end)  
) as lock_conflict  
from t_unionall   
group by   
locktype,datname,relation,page,tuple,virtualxid,transactionid::text,classid,objid,objsubid ;   
EOF
echo "建议: "
echo "    锁等待状态, 反映业务逻辑的问题或者SQL性能有问题, 建议深入排查持锁的SQL. "
echo -e "\n"

echo "----->>>---->>>  继承关系检查: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -q -c 'select inhrelid::regclass,inhparent::regclass,inhseqno from pg_inherits order by 2,3'
done
echo "建议: "
echo "    如果使用继承来实现分区表, 注意分区表的触发器中逻辑是否正常, 对于时间模式的分区表是否需要及时加分区, 修改触发器函数 . "
echo "    建议继承表的权限统一, 如果权限不一致, 可能导致某些用户查询时权限不足. "
echo -e "\n"


echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo "|                      重置统计信息                       |"
echo "|+++++++++++++++++++++++++++++++++++++++++++++++++++++++++|"
echo ""

echo "----->>>---->>>  重置统计信息: "
for db in `psql -p $PGPORT -U $PGUSER --pset=pager=off -t -A -q -c 'select datname from pg_database where datname not in ($$template0$$, $$template1$$)'`
do
psql -p $PGPORT -U $PGUSER -d $db --pset=pager=off -c 'select pg_stat_reset()'
done
psql -p $PGPORT -U $PGUSER --pset=pager=off -c 'select pg_stat_reset_shared($$bgwriter$$)'
psql -p $PGPORT -U $PGUSER --pset=pager=off -c 'select pg_stat_reset_shared($$archiver$$)'

echo "----->>>---->>>  重置pg_stat_statements统计信息: "
psql -p $PGPORT -U $PGUSER --pset=pager=off -q -A -c 'select pg_stat_statements_reset()'

} # common function end


primary() {
if [ -e $PGDATA/recovery.done ]; 
then 
  echo "----->>>---->>>  获取recovery.done配置: "
  grep '^\ *[a-z]' $PGDATA/recovery.done|awk -F "#" '{print $0}'
  echo "建议: "
  echo "    在primary_conninfo中不要配置密码, 容易泄露. 建议为流复制用户创建replication角色的用户, 并且配置pg_hba.conf只允许需要的来源IP连接. "
  echo -e "\n"
fi
} 


standby() {
if [ -e $PGDATA/recovery.conf ]; 
then 
  echo "----->>>---->>>  获取recovery.conf配置: "
  grep '^\ *[a-z]' $PGDATA/recovery.conf|awk -F "#" '{print $0}'
  echo "建议: "
  echo "    在primary_conninfo中不要配置密码, 容易泄露. 建议为流复制用户创建replication角色的用户, 并且配置pg_hba.conf只允许需要的来源IP连接. "
  echo -e "\n"
else
  echo "----->>>---->>>  recovery.conf文件不存在，请确认此数据库是否为备库 或 文件地址是否正确 "
fi

if [ -e $PGDATA/recovery.done ]; 
then 
  echo "----->>>---->>>  获取recovery.done配置: "
  grep '^\ *[a-z]' $PGDATA/recovery.done|awk -F "#" '{print $0}'
  echo "建议: "
  echo "    在primary_conninfo中不要配置密码, 容易泄露. 建议为流复制用户创建replication角色的用户, 并且配置pg_hba.conf只允许需要的来源IP连接. "
  echo -e "\n"
fi
}

if [ $is_standby == 't' ]; then
standby
else
primary
fi

common
cd $pwd
exit 0