#!/bin/sh

if [ -z $1 ]; then
  echo "You must pass the name of the git repos when using this script";
  echo ""
  echo "Usage: "
  echo " $0 <nameofrepos>"
  echo " Example:"
  echo "  git-bare-setup.sh test_app"
  echo ""
  echo "  This will create a post commit that mounts the latest directory in the mount location"
  echo "  under the storage directory in squashfs"
  echo ""
  exit 1;
fi

APP_NAME=$1
PREFIX=/opt/beehive
# Mounts
MOUNT_BASE=$PREFIX/mnt
REPOS_BASE=$PREFIX/repos
SQUASH_BASE=$PREFIX/squashed_fs
SRC_BASE=$PREFIX/src
TMP_DIR=$PREFIX/tmp
FS_DIRECTORY=$SQUASH_BASE/$APP_NAME

MOUNT_FILE=$FS_DIRECTORY/$APP_NAME.sqsh
MOUNT_LOCATION=$MOUNT_BASE/$APP_NAME

cd `dirname $APP_NAME`

if [ ! -d $REPOS_BASE/$APP_NAME ]; then
  echo "mkdir $REPOS_BASE/$APP_NAME"
  mkdir -p $REPOS_BASE/$APP_NAME
fi
if [ ! -d $REPOS_BASE/$APP_NAME.git ]; then
  echo "cd $REPOS_BASE/$APP_NAME && git --bare init"
  cd $REPOS_BASE/$APP_NAME && git --bare init
fi
if [ ! -d $MOUNT_LOCATION ]; then
  mkdir -p $MOUNT_LOCATION
fi
if [ ! -d $FS_DIRECTORY ]; then
  mkdir -p $FS_DIRECTORY
fi


echo "Making post-commit hook"
STR="#!/bin/sh

# Bash script from beehive (http://github.com/auser/beehive.git)
# Runs after a commit and stores sqsh files in $STORE_DIRECTORY

DATE=\$(date +%s)
TIMESTAMPED_NAME=$APP_NAME-\$DATE.sqsh
GIT_REPOS=\$(pwd)
TMP_GIT_CLONE=$TMP_DIR/$APP_NAME

# Now chroot here
mkdir -p \$TMP_GIT_CLONE
cd \$TMP_GIT_CLONE

# Checkout the git repos
mkdir -p \$TMP_GIT_CLONE/home
mkdir -p \$TMP_GIT_CLONE/bin
mkdir -p \$TMP_GIT_CLONE/etc
mkdir -p \$TMP_GIT_CLONE/usr
mkdir -p \$TMP_GIT_CLONE/lib
mkdir -p \$TMP_GIT_CLONE/var
mkdir -p \$TMP_GIT_CLONE/proc
git clone \$GIT_REPOS \$TMP_GIT_CLONE/home/app

# Make the squashfs filesystem
mksquashfs \$TMP_GIT_CLONE $FS_DIRECTORY/\$TIMESTAMPED_NAME

# Link it
ln -sf $FS_DIRECTORY/\$TIMESTAMPED_NAME $MOUNT_FILE

# Get it ready to mount

# Make sure it's in the fstab so it will auto mount on reboot
if [ \$( grep \"$APP_NAME\" /etc/fstab | wc -l) -eq 0 ]; then
  echo \"$MOUNT_FILE $MOUNT_LOCATION squashfs  ro,users,auto,nohide 0 0\" >> /etc/fstab
fi

# Unmount the old one
if [ ! \$(mount | grep -q $APP_NAME) ]; then
  for i in \$(mount | grep $APP_NAME | awk '{print \$1}'); do
    echo 'unmounting \$i'
    sudo umount \$i
  done
fi

# Create the directory at the mount location

# Mount the new one!
if [ ! -d $MOUNT_LOCATION ]; then
  mkdir -p $MOUNT_LOCATION
  mkdir -p $MOUNT_LOCATION/home/app
  mkdir -p $MOUNT_LOCATION/bin
  mkdir -p $MOUNT_LOCATION/etc
  mkdir -p $MOUNT_LOCATION/usr
  mkdir -p $MOUNT_LOCATION/lib
  mkdir -p $MOUNT_LOCATION/home
  mkdir -p $MOUNT_LOCATION/var
fi

# Chroot
cd $MOUNT_LOCATION
sudo chroot $MOUNT_LOCATION

sudo mount $MOUNT_FILE $MOUNT_LOCATION/home/app -t squashfs -o loop

# Bind mount the system
sudo mount --bind /bin $MOUNT_LOCATION/bin -o ro
sudo mount --bind /etc $MOUNT_LOCATION/etc -o ro
sudo mount --bind /usr $MOUNT_LOCATION/usr -o ro
sudo mount --bind /lib $MOUNT_LOCATION/lib -o ro
sudo mount --bind /var $MOUNT_LOCATION/var -o ro

# Start rails
if [ -f $MOUNT_LOCATION/home/app/script/server ]; then
  /bin/bash $MOUNT_LOCATION/home/app/script/server
fi

# Clean up
rm -Rf \$TMP_GIT_CLONE
"

echo "$STR" > hooks/post-receive
chmod +x hooks/post-receive

STR="
  The repos is all setup.
  
  In your local repos, run:
    git remote add origin ssh://SERVER_NAME$REPOS_BASE/$APP_NAME
  
  Where the SERVER_NAME is the name of this server
"
echo "$STR"