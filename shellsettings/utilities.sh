function col {
  awk -v col=$1 '{print $col}'
}

function scratch {
  if [ "$#" -ne 1 ] 
  then
    subl ~/Projects/vistacore/utilities/scratch/$(openssl rand -base64 10 | tr -dc 'a-zA-Z').txt
  else
    subl ~/Projects/vistacore/utilities/scratch/$(openssl rand -base64 10 | tr -dc 'a-zA-Z').$1
  fi
}

function sr {
    find . -type f -exec sed -i '' s/$1/$2/g {} +
}

function skip {
    n=$(($1 + 1))
    cut -d' ' -f$n-
}

function greph {
  grep -riIn $1 .
}

function gitreset {
  git reset --hard HEAD
}
