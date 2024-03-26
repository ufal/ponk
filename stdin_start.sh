
echo "Analyzing input text" >err

echo "Toto je nadpis\n----------- \n\nToto je první věta prvního odstavce." |\
./system/ponk.pl --stdin --output-format conllu 2>>err

echo "Analysis finished." >>err
