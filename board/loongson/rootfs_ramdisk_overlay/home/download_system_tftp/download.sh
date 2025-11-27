#! /bin/sh

###1 dont delete
tftp_ip=$1
rootfs_name=rootfs.tar.gz
rootfs_img_xz_name=rootfs.img.xz
rootfs_img_name=rootfs.img
md5_name=md5.txt
uImage_name=uImage
recover_name=ramdisk.gz
recover_local_name=ramdisk.gz

download_mount_point=$2

download_rootfs_path="$download_mount_point/$rootfs_name"
download_rootfs_img_xz_path="$download_mount_point/$rootfs_img_xz_name"
download_rootfs_img_path="$download_mount_point/$rootfs_img_name"
download_md5_path="$download_mount_point/$md5_name"
download_uImage_path="$download_mount_point/$uImage_name"
download_recover_path="$download_mount_point/$recover_local_name"

root_partition="/dev/sda1"
data_partition="/dev/sda2"
swap_partition="/dev/sda3"
backup_partition="/dev/sda4"

###2 dont delete

install_target_type=0

check_cmdline_ins_target()
{
	install_target_type=0
	# install_target_type=$(cat /proc/cmdline | grep ins_target="scsi") #default is scsi
	install_target_type=$(cat /proc/cmdline | grep ins_target=mmc)
	if [ ! -z "$install_target_type" ]; then
		install_target_type=1
		root_partition="/dev/mmcblk0p1"
		data_partition="/dev/mmcblk0p2"
		swap_partition="/dev/mmcblk0p3"
		backup_partition="/dev/mmcblk0p4"
		return 0
	fi

	root_partition="/dev/sda1"
	data_partition="/dev/sda2"
	swap_partition="/dev/sda3"
	backup_partition="/dev/sda4"
	install_target_type=0
}

error_inf_print()
{
	echo "";
	echo "*************************************************************************"
	echo "********************************Error Log********************************"
	echo "*************************************************************************"
	echo $1
	sleep 2
	echo "*************************************************************************"
	echo ""
	exit 1;
}

#检查文件是否齐全
check_file_for_safe()
{
	#检查是不是缺少部分文件，不然分了区才说没文件系统，那么原来的系统就会丢失。
	#能来这里执行，就代表本来就有uImage
	echo "-------------> stage1 check_file_for_safe <-------------"
	if [ ! -f "$download_rootfs_path" ] && [ ! -f "$download_rootfs_img_path" ]; then
		error_inf_print "Error! not found "$rootfs_name" or "$rootfs_img_name" download failed!"
		exit 1;
	fi
	if [ ! -f "$download_uImage_path" ]; then
		error_inf_print "Error! not found "$uImage_name" download failed!"
		exit 1;
	fi
}

download_system()
{
	# 尝试下载 rootfs.img.xz，如果失败则下载 rootfs.img
	echo "try download $rootfs_img_xz_name...."
	tftp -l "$download_rootfs_img_xz_path" -r $rootfs_img_xz_name -g $tftp_ip -b 65535 2>/dev/null

	if [ ! -f "$download_rootfs_img_xz_path" ]; then
		# 尝试下载 rootfs.img
		echo "try download $rootfs_img_name...."
		tftp -l "$download_rootfs_img_path" -r $rootfs_img_name -g $tftp_ip -b 65535 2>/dev/null
	else
		echo "$rootfs_img_xz_name download success!"
		pv "$download_rootfs_img_xz_path" | xz -d > "${download_rootfs_img_path}"
		rm "$download_rootfs_img_xz_path"
	fi

	if [ ! -f "$download_rootfs_img_path" ]; then
		echo "$rootfs_name downloading...."
		tftp -l "$download_rootfs_path" -r $rootfs_name -g $tftp_ip -b 65535
	else
		echo "$rootfs_img_name download success!"
	fi

	echo "$uImage_name downloading...."
	tftp -l "$download_uImage_path" -r $uImage_name -g $tftp_ip -b 4096

	if [ ! -z $md5_name ]; then
		tftp -l "$download_md5_path" -r $md5_name -g $tftp_ip 2>/dev/null

		if [ -f "$download_md5_path" ]; then
			if [ ! -f "$download_rootfs_path" ] && [ ! -f "$download_rootfs_img_path" ]; then
				# 检查 rootfs.img 的 MD5，如果不存在则检查 rootfs.tar.gz
				if [ -f "$download_rootfs_img_path" ]; then
					ori_md5=$(cat "$download_md5_path" | cut -d ' ' -f1);
					local_md5=$(md5sum "$download_rootfs_img_path" | cut -d ' ' -f1);
				elif [ -f "$download_rootfs_path" ]; then
					ori_md5=$(cat "$download_md5_path" | cut -d ' ' -f1);
					local_md5=$(md5sum "$download_rootfs_path" | cut -d ' ' -f1);
				fi

				if [ "$ori_md5" == "$local_md5" ]; then
					echo "md5 check success!!!";
				else
					error_inf_print "md5 check failed!!! remove rootfs file";
					if [ -f "$download_rootfs_img_path" ]; then
						rm "$download_rootfs_img_path"
					fi
					if [ -f "$download_rootfs_path" ]; then
						rm "$download_rootfs_path"
					fi
				fi

				rm "$download_md5_path"
			fi
		fi
	fi

	if [ -e $backup_partition ]; then
		tftp -l "$download_recover_path" -r $recover_name -g $tftp_ip -b 4096 2>/dev/null
	fi
	check_file_for_safe;
	return $?
}

check_cmdline_ins_target
download_system
exit $?
