#!/bin/bash
# This is a script you can modify and use to create the virtual gpus start the VM and launch looking glass.
# Note that you should change the IDs of the mdevctl vGPUs and the name of the VM "win10"


    exit_handler() {
        exit  # gets caught by trap and goes to terminator
    }
    terminater(){
        echo
        echo "Please turn off the machine from the virt-manager program"
        exit  # Exits normally
    }
trap "terminater" SIGINT SIGTERM

# Ask for password upfront
sudo -v

echo "This will create Virtual GPUs, start the VM, and run looking glass to view it."
echo "Please configure the VM, for example, its USB devices, from the virt-manager program"

echo "Creating Virtual GPUs..."

sudo bash -c '
    mdevctl start -u ce851576-7e81-46f1-96e1-718da691e53e -p 0000:01:00.0 --type nvidia-333
    mdevctl start -u b761f485-1eac-44bc-8ae6-2a3569881a1a -p 0000:01:00.0 --type nvidia-333
    mdevctl define --auto --uuid ce851576-7e81-46f1-96e1-718da691e53e
    mdevctl define --auto --uuid b761f485-1eac-44bc-8ae6-2a3569881a1a
'

# Sometimes LG fails, this prevents that
sudo touch /dev/shm/looking-glass
sudo chmod 777 /dev/shm/looking-glass

echo "Starting Virtual Machine \"win10\""

sudo virsh start win10

count=0
minute=$(date +%M)

# If it restars more than 5 times in a minute, exit.
while true; do
    if [ $(date +%M) != "$minute" ]; then
        count=0
        minute=$(date +%M)
    fi

    looking-glass-client win:fullScreen spice:alwaysShowCursor

    if [ $? -eq 0 ]; then
        count=0
    else
        count=$((count+1))
    fi

    if [ $count -ge 5 ]; then
        echo "Program restarted more than 5 times in a minute. Exiting..."
        exit 1
    fi

    sleep 2
done
 
