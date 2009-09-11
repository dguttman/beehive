#!/bin/bash +x

PREFIX=/opt/beehive
MOUNT_BASE=$PREFIX/mnt
REPOS_BASE=$PREFIX/repos
SQUASH_BASE=$PREFIX/squashed_fs
SRC_BASE=$PREFIX/src
TMP_DIR=$PREFIX/tmp

# This process creates a dyno environment (http://heroku.com/how/dyno_grid)
function build_from_env {  
 
  APP_NAME=$1
  GIT_REPOS=$REPOS_BASE/$APP_NAME
  
  FS_DIRECTORY=$SQUASH_BASE/$APP_NAME
  MOUNT_FILE=$FS_DIRECTORY/$APP_NAME.sqsh  
  
  DATE=$(date +%s)
  TIMESTAMPED_NAME=$APP_NAME-$DATE.sqsh
  TMP_GIT_CLONE=$TMP_DIR/$APP_NAME
  
  # Make the base environment
  mkdir -p $TMP_GIT_CLONE/home
  cd $TMP_GIT_CLONE
  create_chroot_env $TMP_GIT_CLONE
  git clone $GIT_REPOS $TMP_GIT_CLONE/home/app  
  
  # Make the squashfs filesystem
  mksquashfs $TMP_GIT_CLONE $FS_DIRECTORY/$TIMESTAMPED_NAME
  # Link it as the "latest" filesystem
  ln -sf $FS_DIRECTORY/$TIMESTAMPED_NAME $MOUNT_FILE
  mount_and_bind $APP_NAME
  
  # Cleanup
  rm -rf $TMP_GIT_CLONE
}
function mount_and_bind {
  APP_NAME=$1
  MOUNT_LOCATION=$MOUNT_BASE/$APP_NAME
  LOOP_DEVICE=/dev/loop-$APP_NAME
  
  if [ ! -e $LOOP_DEVICE ]; then
    sudo mknod $LOOP_DEVICE b 7 0
  fi
  unmount_already_mounted $MOUNT_LOCATION
  sudo mount $MOUNT_FILE $MOUNT_LOCATION -t squashfs -o loop=$LOOP_DEVICE -o ro

  # Bind mount the system
  sudo mount --bind /bin $MOUNT_LOCATION/bin -o ro
  sudo mount --bind /etc $MOUNT_LOCATION/etc -o ro
  sudo mount --bind /usr $MOUNT_LOCATION/usr -o ro
  sudo mount --bind /lib $MOUNT_LOCATION/lib -o ro
  
  chroot $MOUNT_LOCATION
}
function create_chroot_env {
  CHROOT_DIR=$1
  
  mkdir -p $CHROOT_DIR
  mkdir -p $CHROOT_DIR/{home,etc,bin,lib,usr,usr/bin,dev}
  cd $CHROOT_DIR
  if [ ! -e dev/null ]; then
    sudo mknod dev/null c 1 3
  fi
  if [ ! -e dev/zero ]; then
    sudo mknod dev/zero c 1 5
  fi
}

function unmount_already_mounted {
  MOUNT_LOCATION=$1
  
  MOUNTED=$(mount | grep $MOUNT_LOCATION | awk '{a[i++]=$1} END {for (j=i-1; j>=0;) print a[j--] }')
  for i in $MOUNTED; do
    sudo umount $i
  done
}

function show_usage {
  echo ""
  echo "Usage: $0 (create|destroy) <name>"
  echo ""
}
if [ -z $2 ]; then
  show_usage
  exit 1;
fi
case $1 in
  create )
    build_from_env $2;
    ;;
  destroy )
      unmount_already_mounted $MOUNT_BASE/$2
    ;;
  * )
    show_usage
    exit 1
esac