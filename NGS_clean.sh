#!/bin/bash

# Initialize default option variables if applicable

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
    echo "Usage: bash $0 [-u] [-t] [-r] [-h | -l] <file1> <file2>"
    echo "Options:"
    echo "  -u               Displays this usage message"
    echo "  -t strings       Generate a FASTA file with translated sequences for specified reading frame(s),"
    echo "                   1, 2, 3, -1, -2, -3, and 6 for allsix frames (default [1])"
    echo "  -r string        Provide a reference FASTA/Q file to map sequences to and extract variable region"
    echo "  -h               Generate residue enrichment heatmap for the variable region (constant length only)"
    echo "  -l               Generate histogram of the variable region length distribution (variable length only)"
    exit 1
}

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
