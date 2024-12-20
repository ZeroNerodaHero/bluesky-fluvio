#!/bin/bash
printline(){
    echo "----------------------------------------"
}
printline2(){
    echo "========================================"
}

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         if ($2 == "type") {
            printf("%s\n", $3);
         }
      }
   }'
}
function extract_uses {
    local yaml_file=$1
    awk -v prefix="transforms__" '
    BEGIN { in_transforms = 0 }
    {
        if ($1 ~ /^transforms:/) {
            in_transforms = 1
        } else if (in_transforms && $1 ~ /^-/) {
            if ($2 == "uses:") {
                gsub(/:$/, "", $3)  # Remove the colon from the value
                printf("%s\n", $3);
            }
        } else if (in_transforms && $1 !~ /^[[:space:]]*-/) {
            in_transforms = 0
        }
    }' "$yaml_file"
}

startconnector(){
    package=$(parse_yaml $1)
    sm_type=$(extract_uses $1)
    pkg_file=""

    printline2
    if [ "$sm_type" != "" ]; then
        echo "This connector uses smartmodule $sm_type"
        if fluvio sm list | grep -q "$sm_type"; then
            echo "This already installed $sm_type"
        else
            echo "Installing $sm_type..."
            fluvio hub sm download $sm_type
            echo "Installed $sm_type"
        fi
        printline
    fi
    echo "This connector uses the package $package"
    pkg_name=$(cdk hub list | grep "infinyon/$package" | awk '{print $1}' )
    if [ "$pkg_name" != "" ]; then
        echo "Found the package online under name $pkg_name"
        pkg_file=$(echo "$pkg_name.ipkg" | sed 's/[\/@]/-/g')
        echo "Searching locally for $pkg_file"
        if [ -e "$pkg_file" ]; then
            echo "Package Found."
        else
            echo "Package Not Found. Installing..."
            cdk hub download $pkg_name
        fi
    else
        echo "Cannot find the package online. Aborting"
        exit 1
    fi
    printline

    echo "Running the connector"
    cdk deploy start -c "$1" --ipkg $pkg_file
    echo "Finished running connector 👍"
    printline2
}



if [ -z "$1" ]; then
  echo "Usage: $0 <command>"
  echo "command can be start,clean,status"
  exit 1
fi
if [ "$1" == "clean" ]; then
    connectors=$(cdk deploy list)
    if [ "$connectors" == "No connectors found" ]; then
        echo "No connectors running"
    else
        connectors=$(cdk deploy list | awk '{print $1}' | grep -v 'NAME')
        for connector in $connectors; do
            echo "Deleting connector: $connector"
            cdk deploy shutdown --name ${connector}
        done
    fi
elif [ "$1" == "start" ]; then
    if [ -z "$2" ]; then
        echo "Usage: $0 <connector-file>"
        exit 1
    fi
    startconnector $2
elif [ "$1" == "shutdown" ]; then
    if [ -z "$2" ]; then
        echo "Usage: $0 <name>"
        exit 1
    fi
    cdk deploy shutdown --name $2
elif [ "$1" == "status" ]; then
    printline2
    echo "Status"
    output=$(cdk deploy list)

    echo "$output" | head -n 1

    echo "$output" | tail -n +2 | while read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')
        
        if [[ "$status" == "Running" ]]; then
            color="\033[0;32m"  # Green for Running
        elif [[ "$status" == "Stopped" ]]; then
            color="\033[0;31m"  # Red for Stopped
        else
            color="\033[0m"     # Default color for any other status
        fi

        printf "%b%s\033[0m\n" "$color" "$line"
    done
fi
