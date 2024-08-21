
echo "Analyzing input text" >err

FILE=data/pokus.md

./system/ponk.pl --input-file $FILE --input-format md --output-format html --logging-level 0 --store-format conllu 2>>err

echo "Analysis finished." >>err
