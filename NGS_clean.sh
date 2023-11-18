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
    echo "Usage: bash $0 [-h] [-o dir_name] [-r <file>] [-t F|X] [-v F|X] [-m] [-l] <file1> <file2>"
    echo
    echo "Options:"
    echo "  -h, --help                    Displays this help message"
    echo "  -o, --output_dir string       Provide a name for the output directory. Cannot begin with '-'. Default is <filename>_analysis"
    echo "  -r, --reference string        Provide a reference FASTA/Q file to filter translated sequences by similarity"
    echo "  -t, --translate string        Creates FASTA or XLSX file named <filename>_AA_sequences containing the translated amino acid"
    echo "                                sequences generated during analysis (default XLSX). XLSX files include the number of"
    echo "                                duplicates for each AA sequence. Specify output file type with 'F' or 'X' argument."
    echo "                                Must be used with '--reference' to filter out sequences in undesired reading frames"
    echo "  -v, --variable string         Generate FASTA or XLSX file named <filename>_variable_region containing isolated variable"
    echo "                                region sequences (default XLSX). Specify output file type with 'F' or 'X' argument. Using 'X'"
    echo "                                with '-t X' will add sequences to <filename>_AA_sequences.xlsx instead of creating a new file."
    echo "                                Must be used with '--reference' to filter out sequences in undesired reading frames"
    echo "  -m, --heatmap                 Generate residue enrichment heatmap for the variable region. If input files contain"
    echo "                                sequences with variable length, heatmap will only be generated for sequences with"
    echo "                                same variable region length as the reference sequence. Ouput is saved to a file named "
    echo "                                <filename>_heatmap.pdf in the output directory. Must be used with '--reference'"
    echo "  -l, --length_dist             Generate histogram of the variable region length distribution and save to a file named"
    echo "                                <filename>_histogram.pdf in the output directory. Must be used with '--reference'"
    echo
    exit 1
}

# Function to display script help message
show_help() {
    echo
    echo "This script provides basic statistics on Next-Generation Sequencing (NGS) data generated from site-directed mutagenesis "
    echo "libraries. These stats include the total number of sequences, the average length of the sequences, and more. Sequences"
    echo "with unidentified nucleotides are removed from the dataset. Sequences are translated and those with stop codons and"
    echo "sequencing artifacts are removed from the dataset."
    echo
    echo "Two paths to fastq.gz files are expected as arguments: one for the forward reads and one for the reverse reads. The path"
    echo "to the forward reads (filename with R1) should be first while the path to the reverse reads (filename with R2) should be second."
    echo
    echo "The input DNA sequences are translated and the data is cleaned to isolate relevant protein sequences. The '--translate' option"
    echo "creates a file containing these amino acid sequences while checking for duplicates and providing a frequency statistic."
    echo
    echo "By using the other available options and providing a reference sequence, additional analysis can be performed such as residue"
    echo "enrichment heatmaps and length distibution historgams."
    echo
    echo "If an option is selected that generates a file, a directory titled <filename>_analysis will be created to store the generated file(s)."
    echo
    echo "Usage: bash $0 [-h] [-o dir_name] [-r <file>] [-t F|X] [-v F|X] [-m] [-l] <file1> <file2>"
    echo
    echo "Options:"
    echo "  -h, --help                    Displays this help message"
    echo "  -o, --output_dir string       Provide a name for the output directory. Cannot begin with '-'. Default is <filename>_analysis"
    echo "  -r, --reference string        Provide a reference FASTA/Q file to filter translated sequences by similarity"
    echo "  -t, --translate string        Creates FASTA or XLSX file named <filename>_AA_sequences containing the translated amino acid"
    echo "                                sequences generated during analysis (default XLSX). XLSX files include the number of"
    echo "                                duplicates for each AA sequence. Specify output file type with 'F' or 'X' argument."
    echo "                                Must be used with '--reference' to filter out sequences in undesired reading frames"
    echo "  -v, --variable string         Generate FASTA or XLSX file named <filename>_variable_region containing isolated variable"
    echo "                                region sequences (default XLSX). Specify output file type with 'F' or 'X' argument. Using 'X'"
    echo "                                with '-t X' will add sequences to <filename>_AA_sequences.xlsx instead of creating a new file."
    echo "                                Must be used with '--reference' to filter out sequences in undesired reading frames"
    echo "  -m, --heatmap                 Generate residue enrichment heatmap for the variable region. If input files contain"
    echo "                                sequences with variable length, heatmap will only be generated for sequences with"
    echo "                                same variable region length as the reference sequence. Ouput is saved to a file named "
    echo "                                <filename>_heatmap.pdf in the output directory. Must be used with '--reference'"
    echo "  -l, --length_dist             Generate histogram of the variable region length distribution and save to a file named"
    echo "                                <filename>_histogram.pdf in the output directory. Must be used with '--reference'"
    echo
    exit 1
}

# Function to print to stderr
die() {
    printf '%s\n' "$1" >&2
}

# Enable extended globbing
shopt -s extglob

# Initialize default option variables if applicable

heatmap=false
length_dist=false
translate=false
variable=false
reference=false
output_dir=false

# Loop to parse command line options
while [ : ]; do
    case "$1" in
        -h|--help)          # Displays usage message
            show_help
            exit
            ;;
        -l|--length_dist)   # Executes code to generate histogram
            length_dist=true
            ;;
        -m|--heatmap)       # Executes code to generate heatmap
            heatmap=true
            ;;
        -t|--translate)     # Executes code to translate specified reading frames, takes optional argument
            translate=true
            case "$2" in
                x|X)
                    t_file_type="$2"
                    shift
                    ;;
                f|F)
                    t_file_type="$2"
                    shift
                    ;;
                -?*)        # Matches if option is found after -t, set default file type
                    t_file_type=X
                    ;;
                *.gz)       # Matches if .gz file is found after -t, set default file type
                    t_file_type=X
                    ;;
                *)          # Default case: matches if unexpected argument is found after -t
                    t_file_type=X
                    printf "Warning: Invalid argument for '--translate' (ignored): %s\n" "$2" >&2
                    shift
                    ;;
            esac
            ;;
        -r|--reference)     # Executes code to filter translated sequences using a reference sequence, takes required argument
            case "$2" in
                *.fa|*.fasta)
                    reference=true
                    ref_seq="$2"
                    shift
                    ;;
                *.fq|*.fastq)
                    reference=true
                    ref_seq="$2"
                    shift
                    ;;
                -?*)       # Matches if option is found after -r
                    printf "Warning: An argument is required for '--reference' \n" >&2
                    ;;
                *.gz)      # Matches if .gz file is found after -r
                    printf "Warning: An argument is required for '--reference' \n" >&2
                    ;;
                *)         # Default case: matches if uexpected file type is found
                    printf "Warning: Argument for '--reference' must be in .fa/.fasta or .fq/fastq file format (ignored) \n" >&2
                    shift
                    ;;
            esac
            ;;
        -v|--variable)
            variable=true
            case "$2" in
                x|X)
                    var_file_type="$2"
                    shift
                    ;;
                f|F)
                    var_file_type="$2"
                    shift
                    ;;
                -?*)        # Matches if option is found after -v, set default file type
                    var_file_type=X
                    ;;
                *.gz)       # Matches if .gz file is found after -v, set default file type
                    var_file_type=X
                    ;;
                *)          # Default case: matches if unexpected argument is found after -v
                    var_file_type=X
                    printf "Warning: Invalid argument (ignored): %s\n" "$2" >&2
                    shift
                    ;;
            esac
            ;;
        -o|--output_dir)           # Should also be set to true when -t, -v, -m, -l are used
            output_dir=true
            case "$2" in
                -?*)
                    printf "Warning: No name privided for '--output_dir' (ignored) \n" >&2
                    ;;
                *.gz)
                    printf "Warning: No name privided for '--output_dir' (ignored) \n" >&2
                    ;;
                  *)
                    dir_name="$2"   # Make if statement to check if variable exists.. otherwise use default name
                    shift
                    ;;
            esac
            ;;
        --)                # End of all options
            shift
            break
            ;;
        -?*)
            printf 'Warning: Unkown option (ignored): %s\n' "$1" >&2
            ;;
        *)                 # Default case: No remaining options, break loop
            break
    esac

    shift
done

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

# Check if -o is present and execute associated code
if [ "$output_dir" == true ]; then
    # Initialize a directory count variable
    dir_count=1
    # Set the name for the output directory if not specified
    echo "Insert directory code here"
    if [[ ! -v dir_name ]]; then
        dir_name="${forward_reads_filename}_analysis"
    fi
    # Check if directory by assigned name exsists
    if [ ! -d "$dir_name" ]; then
        mkdir "$dir_name"
    else
        # Increment directory count until available name is found
        while [ -d "${dir_name}(${dir_count})" ]; do
            ((dir_count++))
        done
        dir_name="${dir_name}(${dir_count})"
        mkdir "$dir_name"
    fi
fi

# Check if -r is present and execute associated code
if [ "$reference" == true ]; then
    # Insert reference code here
    echo "Insert reference code here"
fi

# Check if -t is present and execute associated code
if [ "$translate" == true ]; then
    # Check if $reference is true
    if [ "$reference" == true ]; then
        # Insert translate code here
        echo "Insert translate code here"
    else
        die "Error: '--translate' requires a reference sequence."
    fi
fi

# Check if -v is present and execute associated code
if [ "$variable" == true ]; then
    # Check if $reference is true
    if [ "$reference" == true ]; then
        # Insert variable code here
        echo "Insert variable code here"
    else
        die "Error: '--variable' requires a reference sequence."
    fi
fi

# Check if -h is present and execute associated code
if [ "$heatmap" == true ]; then
    # Check if $reference is true
    if [ "$reference" == true ]; then
        # Insert heatmap code here
        echo "Insert heatmap code here"
    else
        die "Error: '--heatmap' requires a reference sequence."
    fi
fi

# Check if -l is present and execute associated code
if [ "$length_dist" == true ]; then
    # Check if reference is true
    if [ "$reference" == true ]; then
        # Insert histogram code here
        echo "Insert histogram code here"
    else
        die "Error: '--length_dist' requires a reference sequence."
    fi
fi

# Rest of script
