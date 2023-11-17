#!/bin/bash

# Function to print a line of a specified character
print_separator() {
    local length=$1
    local char=$2
    for ((i=0; i<$length; i++)); do
        echo -n "$char"
    done
    echo
}

# Function to display script usage
usage() {
    echo "Usage: bash $0 [-h] [-o dir_name] [-t #,#...] [-r <file>] [-v F|X] [-m] [-l] <file1> <file2>"
    echo
    echo "Options:"
    echo "  -h, --help                    Displays this help message"
    echo "  -o, --output_dir string       Provide a name for the output directory. Cannot begin with '-'. Default is <filename>_analysis"
    echo "  -t, --translate strings       Generate <filename>_translated.fasta with translated sequences for specified reading frame(s),"
    echo "                                1, 2, 3, -1, -2, -3, and 6 for all six frames (default [1]). 'clean' must be used with"
    echo "                                '--heatmap', '--length-dist', or '--reference' and will only output sequences used for analysis"
    echo "  -r, --reference string        Provide a reference FASTA/Q file to filter translated sequences by similarity"
    echo "  -v, --variable string         Generate FASTA or XLSX file containing isolated variable region sequences  Specify"
    echo "                                output file type with 'F' or 'X' argument. Must be used with '--reference'"
    echo "  -m, --heatmap                 Generate residue enrichment heatmap for the variable region. If input files contain"
    echo "                                sequences with variable length, heatmap will only be generated for sequences with"
    echo "                                same variable region length as the reference sequence. Must be used with '--reference'"
    echo "  -l, --length_dist             Generate histogram of the variable region length distribution. Must be used with '--reference'"
    echo
    exit 1
}

# Function to display script help message
show_help() {
    echo "This script provides basic statistics on Next-Generation Sequencing (NGS) data generated from site-directed mutagenesis "
    echo "libraries. These stats include the total number of sequences, the average length of the sequences, and more. Sequences"
    echo "with unidentified nucleotides are removed from the dataset. Sequences are translated and those with stop codons and"
    echo "sequencing artifacts are removed from the dataset."
    echo
    echo "Two paths to fastq.gz files are expected as arguments: one for the forward reads and one for the reverse reads. The path"
    echo "to the forward reads (filename with R1) should be first while the path to the reverse reads (filename with R2) should be second."
    echo
    echo "The '--translate' option allows files to be generated containing protein sequences for specified reading frames without filtering."
    echo
    echo "By using the other available options and providing a reference sequence, additional analysis can be performed such as residue"
    echo "enrichment heatmaps and length distibution historgams."
    echo
    echo "If an option is selected that generates a file, a directory titled <filename>_analysis will be created to store the generated file(s)."
    echo
    echo "Usage: bash $0 [-h] [-o dir_name] [-t #,#...] [-r <file>] [-v F|X] [-m] [-l] <file1> <file2>"
    echo
    echo "Options:"
    echo "  -h, --help                    Displays this help message"
    echo "  -o, --output_dir string       Provide a name for the output directory. Cannot begin with '-'. Default is <filename>_analysis"
    echo "  -t, --translate strings       Generate <filename>_translated.fasta with translated sequences for specified reading frame(s),"
    echo "                                1, 2, 3, -1, -2, -3, and 6 for all six frames (default [1]). 'clean' must be used with"
    echo "                                '--heatmap', '--length-dist', or '--reference' and will only output sequences used for analysis"
    echo "  -r, --reference string        Provide a reference FASTA/Q file to filter translated sequences by similarity"
    echo "  -v, --variable string         Generate FASTA or XLSX file containing isolated variable region sequences  Specify"
    echo "                                output file type with 'F' or 'X' argument. Must be used with '--reference'"
    echo "  -m, --heatmap                 Generate residue enrichment heatmap for the variable region. If input files contain"
    echo "                                sequences with variable length, heatmap will only be generated for sequences with"
    echo "                                same variable region length as the reference sequence. Must be used with '--reference'"
    echo "  -l, --length_dist             Generate histogram of the variable region length distribution. Must be used with '--reference'"
    echo
    exit 1
}

# Initialize default option variables if applicable

# Parse command-line options
while getopts "hlu" opt; do
    case $opt in
        h) heatmap=true ;;
        l) length_dist=true ;;
        u) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    esac
done

# Shift to next set of arguments (skip processed options)
shift $((OPTIND-1))

# Check if there are 2 input files
if [ "$#" -ne 2 ]; then
    echo "Error: Two input files are required (forward and reverse reads)."
    usage
fi

# Print initial statistic analysis for both input files

# Forward reads header
echo
forward_reads_filename=$(echo "$1" | cut -d'.' -f1)
print_separator 70 -
echo "$forward_reads_filename Stats:"
print_separator 70 -

# Print statistics for original forward reads data file
echo
echo "Preliminary:"
zcat $1 | seqkit stat

# Print statistics for forward reads without sequences containing unidentified nucleotides
echo
echo "Cleaned:"
zcat $1 | seqkit grep -s -v -p N | seqkit stat

# Define total number of forward read sequences
R1tot_num_seq=$(zcat $1 | seqkit stat | cut -d' ' -f13 | tr -d '\n' | tr -d ',' | tr -d ' ')

# Define number of froward reads without unidentified nucleotides
R1cleaned_num_seq=$(zcat $1 | seqkit grep -s -v -p N | seqkit stat | cut -d' ' -f13 | tr -d '\n' | tr -d ',' | tr -d ' ')

# Define number of forward reads with unidentified nucleotides
R1removed_num_seq=$(echo "$R1tot_num_seq-$R1cleaned_num_seq" | bc)

# Print number of forward read sequences with unidentified nucleotides
echo
echo "Removed $R1removed_num_seq sequences with unidentified base pairs"

# Reverse reads header
echo
reverse_reads_filename=$(echo "$2" | cut -d'.' -f1)
print_separator 70 -
echo "$reverse_reads_filename Stats:"
print_separator 70 -

# Print statistics for original reverse reads data file
echo
echo "Preliminary:"
zcat $2 | seqkit stat

# Print statistics for reverse reads without sequences containing unidentified nucleotides
echo
echo "Cleaned:"
zcat $2 | seqkit grep -s -v -p N | seqkit stat

# Define total number of reverse read sequences
R2tot_num_seq=$(zcat $2 | seqkit stat | cut -d' ' -f13 | tr -d '\n' | tr -d ',' | tr -d ' ')

# Define number of reverse reads without unidentified nucleotides
R2cleaned_num_seq=$(zcat $2 | seqkit grep -s -v -p N | seqkit stat | cut -d' ' -f13 | tr -d '\n' | tr -d ',' | tr -d ' ')

# Define number of reverse reads with unidentified nucleotides
R2removed_num_seq=$(echo "$R2tot_num_seq-$R2cleaned_num_seq" | bc)

# Print number of reverse read sequences with unidentified nucleotides
echo
echo "Removed $R2removed_num_seq sequences with unidentified base pairs"

# Print section separator
echo
print_separator 70 '~'
print_separator 70 '~'
echo

# Options

# Check if -h is present and execute associated code
if [ "$heatmap" == true ]; then
    # Insert heatmap code here
    echo "Insert heatmap code here"
fi

# Check if -l is present and execute associated code
if [ "$length_dist" == true ]; then
    # Insert histogram code here
    echo "Insert histogram code here"
fi

# Rest of script
