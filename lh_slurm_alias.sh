# List unique `who` output
unique_users() {
	who | sort -u | cut -f 1 -d " " | uniq;
}
​
# Get account group GPU limits
account_caps(){
	sacctmgr -nop show assoc format=account,grptres | grep gres | awk -F"[|=]" '{print $1" "$3}'
}
​
# Compute total number of GPUs
total_gpus(){
  scontrol show nodes -o | awk '{print $9}' | grep gpu | awk -F: '{i += $2} END {print i}'
}
​
#Compute maximum number of GPUs available through slurm
avail_gpus(){
	scontrol show nodes -o | grep -v DOWN | grep -v DRAIN | awk '{print $9}' | grep gpu | awk -F: '{i += $2} END {print i}'
}
​
# Compute number of GPUs in use using squeue
srun_gpus() {
	if [ $# -eq 0 ]; then
                echo "IN-USE / AVAILABLE / TOTAL"
		AVAIL_GPUS=`avail_gpus`
                TOTAL_GPUS=`total_gpus`
		squeue -o '%b %t' | grep gpu | grep R | sed 's/gpu:[a-zA-Z_:$]*//g' | awk '{i += $1;} END {printf "%d",i}'; echo " / $AVAIL_GPUS / $TOTAL_GPUS"
	elif [ $# -eq 1 ]; then
		squeue -o '%b %t %u' | grep gpu | grep $1 | grep R | sed 's/gpu:[a-zA-Z_:$]*//g' | awk '{i += $1;} END {print i}'
	else
		echo "srun_gpus does not accept more than 1 argument"
	fi
}
​
used_gpus(){
    scontrol show nodes -o | grep "jiadeng\|justincj" | grep -v DOWN | grep -v DRAIN | awk '{print $38}' | awk -F, -F= '{i += $5} END {print i}'
}

used_2080(){
    scontrol show nodes -o | grep "jiadeng\|justincj" | grep -v DOWN | grep -v DRAIN | grep 2080 | awk '{print $38}' | awk -F, -F= '{i += $5} END {print i}'
}

used_1080(){
    scontrol show nodes -o | grep "jiadeng\|justincj" | grep -v DOWN | grep -v DRAIN | grep titan | awk '{print $38}' | awk -F, -F= '{i += $5} END {print i}'
}

​
# Compute number of GPUs which are in line to be scheduled.
scheduled_gpus() {
  if [ $# -eq 0 ]; then
    squeue -o '%b %t' | grep gpu | grep "R\|PD" | sed 's/gpu://g' | awk '{i += $1;} END {print i}'
  elif [ $# -eq 1 ]; then
      squeue -o '%b %t %u' | grep gpu | grep $1 | grep "R\|PD" | sed 's/gpu://g' | awk '{i += $1;} END {print i}'
  else
    echo "srun_gpus does not accept more than 1 argument"
  fi
}
alias gpus_scheduled=scheduled_gpus
​
# GPU Usage by user
usage_by_user() {
        squeue -o "%u %t %b %D" -h | grep gpu | grep R | sort | awk -F'[ :]' '{if(name==$1){ count+= $(NF) * $(NF - 1);}else{ print name" "count; name=$1; count=$(NF) * $(NF - 1);}} END{print name" "count;}'	
}
​
# GPU Usage by lab
usage_by_lab() {
        squeue -o "%a %t %b %D" -h | grep gpu | grep R | sort | awk -F'[ :]' '{if(name==$1){ count+= $(NF) * $(NF - 1);}else{ print name" "count; name=$1; count=$(NF) * $(NF - 1);}} END{print name" "count;}'	
}
​
#GPUs scheduled by lab
scheduled_gpus_by_lab() {
	squeue --format="%a %b %t" | grep gpu | grep "R\|PD" | sed 's/gpu[:A-Za-z0-9_]*://g' |sort | awk -F'[ :]' '{if(name==$1){ count+=$2;}else{ print name" "count; name=$1; count=$2;}} END{print name" "count;}' | tail -n +2
}
​
# Automatically generate the string for slurm's --exclude argument by filtering out the nodes with CPU load average greater than a fixed value (= 28 for now, since there are 28 cores for each machine)
filter_cpu_avail_nodes() {
	sinfo --format '%10n %8O' | awk 'NR>1{if ($2 > 28.0) print $1}' | paste -s -d, -	
}
# An example of blacklisted nodes (should be changed according to your preference)
export BLACK_LIST_NODES="gl1001,gl1002"
exclude_list() {
	exclude_str="$BLACK_LIST_NODES"
	filt_nodes=`filter_cpu_avail_nodes`
	if [ -z "$filt_nodes" ]; then
		true
	else
		if [ -z "$exclude_str" ]; then
			exclude_str="$filt_nodes"
		else
			exclude_str="$exclude_str,$filt_nodes"
		fi
	fi
	if [ -z "$exclude_str" ]; then
		printf $exclude_str
	else
		printf -- '--exclude '
		printf $exclude_str | sed 's/,/\n/g' | sort | uniq | paste -s -d, -
	fi
}
​
alias gpus_running=srun_gpus
alias gpus_users=usage_by_user
alias gpus_labs=usage_by_lab
alias sload="sinfo --format '%10n %8O %e'"
​
# Compute total number of free GPUs.
free_gpus(){
  AVAIL_GPUS=`avail_gpus`
  RUN_GPUS=`gpus_scheduled`
  echo $((AVAIL_GPUS - RUN_GPUS))
}
​
# Get per lab usage and their associated caps
lab_use(){
	join <(usage_by_lab) <(scheduled_gpus_by_lab) | join - <(account_caps) | awk 'BEGIN {print "Account \t Used / Sched / Cap"} {print $1" \t "$2" / " $3 " / " $4}'
}
