#mkdir  home/assignment/submission
inputFileArg="$1"
ReadArray=() 
lineNumber=-1
while IFS= read -r line 
do 
 trimmedLine=$(echo "$line" | sed -e 's/^[ \t\r]*//' -e 's/[ \t\r]*$//') 
 ReadArray+=("$trimmedLine") 
  ((lineNumber++))   
done < "$inputFileArg"
echo "Line count: $lineNumber"
if [ "$lineNumber" -ne 11 ]; then
   echo "Invalid file: input.txt does not contain 11 lines."
    exit 1
else
  echo "File is valid. Proceeding with processing."
fi

IFS=' ' 
format="${ReadArray[0]}"
for word in ${ReadArray[1]} 
do 
  isArchived+=("$word") 
done 
echo ${isArchived[@]}
for word in ${ReadArray[2]} 
do 
  filetype+=("$word") 
done 
echo ${filetype[@]}

full_marks="${ReadArray[3]}"
mismatched_penalty="${ReadArray[4]}"
Working_Directory="${ReadArray[5]}"
for id in ${ReadArray[6]} 
do 
  id_range+=("$id") 
done 
echo ${id_range[@]}
Expected_Output_File_Location="${ReadArray[7]}"
Guidelines_Violations_penalty="${ReadArray[8]}"
Plagiarism_analysis="${ReadArray[9]}"
Plagiarism_Penalty="${ReadArray[10]}"
echo "Full marks: $full_marks"

cd home/assignment
touch marks.csv
echo 'id','marks','marks_deducted','total_marks','remarks' > marks.csv
file2="marks.csv"
for (( student="${id_range[0]}"; student<="${id_range[1]}"; student++ )) do
 echo "$student,$full_marks,0,$full_marks,">> "$file2"
done

mkdir -p submission
 touch expected_output.txt
 touch plagiarism.txt


mapfile -t plagiarism_ids < plagiarism.txt
echo "Plagiarized IDs:"
for id in "${plagiarism_ids[@]}"; do
  echo "$id"
done

is_plagiarized()
{
 local s_id="$1"
 for id in "${plagiarism_ids[@]}"; do
 if [[  "$id" == "$s_id" ]]; then           
   return 0
 fi
done
return 1  
}

for cmd in unzip tar unrar; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd command not found. Please install it."
        exit 1
    fi
done


initialize_marks()
{
  for id  in "${id_range[@]}"; do
  echo "$id,$full_marks,0,$full_marks,"
  done  

}

declare -A deducedMarks
declare -A remarksStore
declare -A debug

update_marks()
{  
    local id="$1"
local deducted_marks="$2"
local remarks="$3"
local total_marks=$((full_marks-deducted_marks))
    temData="$id,$full_marks,$deducted_marks,$total_marks,$remarks"
    echo "$temData" >> "marks.csv"

}

ISSUES_DIR="issues"
CHECKED_DIR="checked"

create_or_clear_dir() {
    local dir="$1"   
    if [ -d "$dir" ]; then
      echo "Directory $dir already exists. Clearing."
     rm -rf "$dir"/*
    else
   echo "Directory $dir does not exist. Creating "
      mkdir "$dir"
    fi
}

create_or_clear_dir "$ISSUES_DIR"
create_or_clear_dir "$CHECKED_DIR"
extension=("c" "cpp" "py" "sh")

check_files()
{  
     local dir="$1"
local issues_dir="issues"
 local check_dir="checked"
echo "Checking files in $dir:"
find "$dir" -type f | while read -r file; do
    ext="${file##*.}"  
    valid=false
    for allowed_ext in "${filetype[@]}"; do
         if [[ "$ext" == "$allowed_ext" ]]; then
            valid=true
             break
        fi
     done     
    if [ "$valid" = true ]; then
        echo "File: $(basename "$file") | Format: .$ext | Status: Valid"
        Run_code "$file" "$ext"
        mv "$dir" "$check_dir/"
        else
        echo "File: $(basename "$file") | Format: .$ext | Status: Invalid"
        update_marks "$(basename "$file" | cut -d'.' -f1)" "$full_marks" "case#3"
        mv "$dir" "$issues_dir/"
        fi
 done
   
}



matchOutput()
{ 
    missing=0 
    while IFS= read -r expected_line; do 
        # Check if the expected line exists in the output file 
        if ! grep -Fxq "$expected_line" "$1"; then 
            missing=$((missing + 1)) 
        fi 
    done < "expected_output.txt" 
    marks=$((missing * mismatched_penalty)) 
    echo $marks 
}


Run_code()
   {
     submission_dir=$(basename "$(dirname "$file")") 
     base_name="${submission_dir%.*}"
    student_id=$(basename "$(dirname "$(dirname "$(dirname "$file")")")")
    case "$ext" in
    c)
     echo "Compiling and Running $file"
    gcc "$file" -o "${file%.c}.out"
    if [ $? -eq 0 ]; then
        ./"${file%.c}.out" > "${file%.c}_output.txt"
       fi
       ;;
    cpp)
       echo "Compiling and Running $file"
       g++ "$file" -o "${file%.cpp}.out"
       if [ $? -eq 0 ]; then
        ./"${file%.cpp}.out" > "${file%.cpp}_output.txt"
    fi
       ;;
    py)
    echo "Running Python script $file"
    python3 "$file" > "${file%.py}_output.txt"
    ;;
    sh)
    echo "Running Shell Script $file"
     bash "$file" > "${file%.sh}_output.txt"
    ;;
    *)
    echo "Unsupported file type: $ext"
    ;;
 esac  
 if [ -f "expected_output.txt" ]; then 
 echo "Comparing output with expected_output.txt"
    matchNumber=$(matchOutput "${file%.*}_output.txt")
    update_marks "$base_name" "$matchNumber" ""
 else
   echo "expected_output.txt not found!"
 fi

 if is_plagiarized "$base_name"; then
  echo "Plagiarized: $base_name "
  update_marks "$base_name" "$Plagiarism_Penalty" "Penalty"
fi
}
    

process_directory()
 {
local dir="$1"
    if [ -z "$(ls -A "$dir")" ]; then
    echo "Directory $dir is empty, moving to issues directory."
    mv "$dir" "issues/"
    return  
 fi

echo "Processing directory: $dir"
 find "$dir" -type f | while read -r file; do
    ext="${file##*.}"
    if [[ " ${filetype[@]} " == *" $ext "* ]]; then
    echo "Processing file: $(basename "$file")"
    Run_code "$file" "$ext"
    else
     echo "Skipping file: $(basename "$file") (Unsupported format)"
    fi
 done
}




process1()
 {
 local file="$1"
 local dir="${file%.zip}"   
  mkdir -p "$dir"
  unzip "$file" -d "$dir" > /dev/null 2>&1 
    internal_folder=$(find "$dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)  
    if [ -n "$internal_folder" ]; then  
        internal_folder_name=$(basename "$internal_folder")  
        if [ "$internal_folder_name" == "$(basename "$dir")" ]; then
        echo "Folder inside the zip file matches the zip file name."
        else
         echo "Folder inside the zip file does NOT match the zip file name."          
     fi
 else
  echo "No folder found inside the zip file!"
 fi
    check_files "$dir"
}

process2()
{ 
     local file="$1"
local dir="${file%.rar}"  
  mkdir -p "$dir"
  unrar "$file" -d "$dir" > /dev/null 2>&1 
    internal_folder=$(find "$dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)  
    if [ -n "$internal_folder" ]; then  
        internal_folder_name=$(basename "$internal_folder")  
        if [ "$internal_folder_name" == "$(basename "$dir")" ]; then
        echo "Folder inside the rar file matches the rar file name."
        else
         echo "Folder inside the rar file does NOT match the rar file name."          
     fi
 else
  echo "No folder found inside the zip file!"
 fi
    check_files "$dir"
}


process3()
{ 
       local file="$1"
local dir="${file%.tar}"  
  mkdir -p "$dir"
  tar -xvf "$file" -C "$dir" > /dev/null 2>&1 
    internal_folder=$(find "$dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)  
    if [ -n "$internal_folder" ]; then  
     internal_folder_name=$(basename "$internal_folder")  
     if [ "$internal_folder_name" == "$(basename "$dir")" ]; then
     echo "Folder inside the tar file matches the tar file name."
     else
     echo "Folder inside the tar file does NOT match the tar file name."          
 fi
 else
  echo "No folder found inside the tar file!"
 fi
check_files "$dir"
   
}


is_in_range()
{
    local zip_name="$1"
   local lower="${id_range[0]}"
   local upper="${id_range[-1]}"

   if [[ "$zip_name" -ge "$lower" && "$zip_name" -le "$upper" ]]; then 
     return 0
 else 

     return 1   
  fi   
}

check_format()
{  local ext="$1"
   for element in "${isArchived[@]}"; do 
    if [[ "$ext" == "$element" ]];  then
       return 0
    fi
 done 
return 1;    
}


for file in submission/*; do
    if [ -e "$file" ]; then
      if [ -d "$file" ]; then
        base_name=$(basename "$file")
         if is_in_range "$base_name"; then
         update_marks "$base_name" "$Guidelines_Violations_penalty" "case1"
         process_directory "$file"
            #mv "$file" "issues/"
    fi
      else
         
    file_basename=$(basename "$file")
     ext="${file_basename##*.}"
    zip_name="${file_basename%.zip}"
   tar_name="${file_basename%.tar}"
     rar_name="${file_basename%.rar}"
         if check_format "$ext"; then
         case "$file" in
      *.zip)    
     if is_in_range "$zip_name"; then

       echo "Processing Zip file: $(basename "$file")"
       process1 "$file"    
        else
        update_marks "$zip_name" "$full_marks" "case#5"
        mv "$file" "issues/"
        fi
        ;;
      *.rar)
         if is_in_range "$rar_name"; then
        echo "Processing rar file: $(basename "$file")"
        process2 "$file"
         else
         update_marks "$rar_name" "$full_marks" "case#5"
            mv "$file" "issues/"
        fi 
        ;;
      *.tar)
       if is_in_range "$tar_name"; then
         echo "Processing tar file: $(basename "$file")"
        process3 "$file"
        else
        update_marks "$tar_name" "$full_marks" "case#5"
        mv "$file" "issues/"
        fi
        
         ;;  
       *)
        echo "File $(basename "$file") is not a recognized type"
        ;;
      esac
    fi
    fi
 fi
done


