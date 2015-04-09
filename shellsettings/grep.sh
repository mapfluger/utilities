echo "grep -riIn --include \*.filetype 'regex' ."
printf 'Enter filetype : '
read -r filetype
printf 'Enter regex : '
read -r regex
if [ -z $filetype ]; then
  grep -riIn $regex .
  exit 0
fi
grep -riIn --include \*.$filetype $regex .
