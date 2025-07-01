#!/bin/bash
echo "script is running.."
# Define the file paths
USER_FILE="users.txt"
IN_PROGRESS_ORDERS="in_progress_orders.txt"
HISTORY_FILE="history.txt"
PREPAID_FILE="prepaid.txt"
ADMIN_FILE="admin.txt"
PREPAID_REQUESTS="prepaid_requests.txt"

# Initialize files if not already present
if [ ! -f $USER_FILE ]; then
    touch $USER_FILE
fi



if [ ! -f $HISTORY_FILE ]; then
    touch $HISTORY_FILE
fi

if [ ! -f $PREPAID_FILE ]; then
    touch $PREPAID_FILE
fi

if [ ! -f $ADMIN_FILE ]; then
    touch $ADMIN_FILE
fi

if [ ! -f $PREPAID_REQUESTS ]; then
    touch $PREPAID_REQUESTS
fi

# Admin Registration
admin_register() {
    clear
    echo "---------------------------------"
    echo "       Admin Registration "
    echo "---------------------------------"

    read -p "Enter admin username: " admin_username
    read -p "Enter admin email: " admin_email
    read -s -p "Enter admin password: " admin_password
    echo

    # Check if the admin already exists
    if grep -q "$admin_username" $ADMIN_FILE; then
        echo "Admin username already exists! Please choose another username."
        read -p "Press any key to return to the welcome screen..." key
        welcome_screen
    else
        # Register the new admin
        echo "$admin_username:$admin_email:$admin_password" >> $ADMIN_FILE
        echo "Admin registration successful! You can now log in."
        read -p "Press any key to return to the welcome screen..." key
        welcome_screen
    fi
}

# Admin Login
admin_login() {
    clear
    echo "---------------------------------"
    echo "       Admin Login "
    echo "---------------------------------"

    read -p "Enter admin username: " admin_username
    read -s -p "Enter admin password: " admin_password
    echo

    login_successful=false

    while IFS=: read -r stored_admin stored_email stored_pass; do
        if [[ "$admin_username" == "$stored_admin" && "$admin_password" == "$stored_pass" ]]; then
            login_successful=true
            break
        fi
    done < "$ADMIN_FILE"

    if [ "$login_successful" = true ]; then
        echo "Admin login successful!"
        admin_menu
    else
        echo "Invalid admin username or password."
        read -p "Press any key to return to the welcome screen..." key
        welcome_screen
    fi
}

# Admin Menu
admin_menu() {
    clear
    echo "---------------------------------"
    echo "       Admin Dashboard"
    echo "---------------------------------"
    echo "1. View Pending Requests"
    echo "2. Approve/Reject Print Requests"
    echo "3. View Completed Requests"
    echo "4. Approve/Reject Prepaid Packages"
    echo "5. View Prepaid Packages of All Users"
    echo "6. Logout"
    read -p "Choose an option: " admin_option
    case $admin_option in
        1) view_all_requests ;;
        2) approve_reject_requests ;;
        3) view_completed_requests ;;
        4) approve_reject_prepaid ;;
        5) view_all_prepaid_packages ;;   
        6) welcome_screen ;;
        *) echo "Invalid option." ; read -p "Press any key to return..." key ; admin_menu ;;
    esac
}
#View all prepaid packages
view_all_prepaid_packages() {
    clear
    echo "---------------------------------"
    echo "  Prepaid Packages of All Users"
    echo "---------------------------------"

    if [ ! -s "$PREPAID_FILE" ]; then
        echo "No prepaid packages found."
    else
        echo "Username            Transaction ID          Pages Remaining"
        echo "------------------------------------------------------------"

        awk -F: '
        function trim(s) {
            gsub(/^[ \t]+|[ \t]+$/, "", s)
            return s
        }
        {
            username = trim($1)
            transaction = trim($2)
            pages = trim($3)

            # Skip entries with empty username or pages or transaction
            if (username == "" || transaction == "" || pages == "") {
                next
            }

            # Skip username with spaces (likely invalid or corrupted)
            if (username ~ / /) {
                next
            }

            if (username != prev_user) {
                # print blank line between users for clarity (except first)
                if (NR > 1) print ""
                printf "%-20s %-25s %s\n", username, transaction, pages
            } else {
                printf "%-20s %-25s %s\n", "", transaction, pages
            }
            prev_user = username
        }
        END {
            print "------------------------------------------------------------"
        }
        ' "$PREPAID_FILE"
    fi

    echo
    read -p "Press any key to return to the admin menu..." key
    admin_menu
}

# View pending print requests
view_all_requests() {
    clear
    echo "---------------------------------"
    echo "       Pending Print Requests"
    echo "---------------------------------"

    if [ -s "$IN_PROGRESS_ORDERS" ]; then
        cat "$IN_PROGRESS_ORDERS"
    else
        echo "No print requests found."
    fi

    echo
    read -p "Press any key to return to the admin menu..." key
    admin_menu
}

# Approve or reject print requests
approve_reject_requests() {
    clear
    echo "---------------------------------"
    echo "  Approve/Reject Print Requests"
    echo "---------------------------------"

    if [ ! -s "$IN_PROGRESS_ORDERS" ]; then
        echo "No print requests to manage."
        read -p "Press any key to return to the admin menu..." key
        admin_menu
        return
    fi

    # Display all pending requests with OrderIDs
    grep "OrderID:" "$IN_PROGRESS_ORDERS" | while read -r line; do
        order_id=$(echo "$line" | awk '{print $2}')
        username_line=$(grep -A 10 "$line" "$IN_PROGRESS_ORDERS" | grep "Username:")
        file_line=$(grep -A 10 "$line" "$IN_PROGRESS_ORDERS" | grep "File:")
        status_line=$(grep -A 10 "$line" "$IN_PROGRESS_ORDERS" | grep "Status:")
        
        echo "OrderID: $order_id"
        echo "$username_line"
        echo "$file_line"
        echo "$status_line"
        echo "-----------------------------"
    done

    read -p "Enter OrderID to manage (or '0' to cancel): " order_id
    if [ "$order_id" == "0" ]; then
        admin_menu
        return
    fi

    if ! grep -q "OrderID: $order_id" "$IN_PROGRESS_ORDERS"; then
        echo "Invalid OrderID."
        read -p "Press any key to try again..." key
        approve_reject_requests
        return
    fi

    echo "1. Approve"
    echo "2. Reject"
    read -p "Choose action (1/2): " action

    case $action in
        1) new_status="Approved" ;;
        2) new_status="Rejected" ;;
        *) echo "Invalid choice." ; read -p "Press any key to try again..." key ; approve_reject_requests ; return ;;
    esac

    # Update the status in in_progress_orders.txt
    awk -v order_id="$order_id" -v new_status="$new_status" '
    /OrderID: / { 
        if ($2 == order_id) { 
            in_block=1 
        } else { 
            in_block=0 
        } 
    } 
    in_block && /Status: / { 
        $0 = "Status: " new_status 
    } 
    { print } 
    ' "$IN_PROGRESS_ORDERS" > temp.txt && mv temp.txt "$IN_PROGRESS_ORDERS"

    # If approved, move to history.txt
if [ "$new_status" == "Approved" ]; then
    awk -v order_id="$order_id" '
    /OrderID: / {
        if ($2 == order_id) {
            in_block=1
        } else {
            in_block=0
        }
    }
    in_block { print }
    /^-----------------------------$/ && in_block {
        print
        in_block=0
    }
    ' "$IN_PROGRESS_ORDERS" >> "$HISTORY_FILE"

    # Deduct prepaid pages if payment method was prepaid
    payment_method=$(awk -v id="$order_id" '
        $0 ~ "OrderID: "id {found=1}
        found && /Payment Method:/ {
            split($0, a, ": ")
            print tolower(a[2])
            exit
        }
    ' "$HISTORY_FILE")

    if [ "$payment_method" = "prepaid" ]; then
        username=$(awk -v id="$order_id" '
            $0 ~ "OrderID: "id {found=1}
            found && /Username:/ {
                split($0, a, ": ")
                print a[2]
                exit
            }
        ' "$HISTORY_FILE")

        pages_per_copy=$(awk -v id="$order_id" '
            $0 ~ "OrderID: "id {found=1}
            found && /Pages per Copy:/ {
                split($0, a, ": ")
                print a[2]
                exit
            }
        ' "$HISTORY_FILE")

        copies=$(awk -v id="$order_id" '
            $0 ~ "OrderID: "id {found=1}
            found && /Copies:/ {
                split($0, a, ": ")
                print a[2]
                exit
            }
        ' "$HISTORY_FILE")

        # Validate numeric input
        if [[ "$pages_per_copy" =~ ^[0-9]+$ && "$copies" =~ ^[0-9]+$ ]]; then
            pages_requested=$((pages_per_copy * copies))

            # Deduct from the first package with enough pages
            awk -v user="$username" -v pages="$pages_requested" -F: '
            BEGIN { OFS = ":"; deducted = 0 }
            {
                if ($1 == user && deducted == 0 && $3 >= pages) {
                    $3 -= pages
                    deducted = 1
                }
                print
            }
            ' "$PREPAID_FILE" > temp.txt && mv temp.txt "$PREPAID_FILE"
        else
            echo "Error: Invalid pages or copies value."
        fi
    fi

        # Remove from in_progress_orders.txt
        awk -v order_id="$order_id" '
        /OrderID: / { 
            if ($2 == order_id) { 
                in_block=1 
                skip=1 
            } else { 
                in_block=0 
                skip=0 
            } 
        } 
        /^-----------------------------$/ && in_block { 
            in_block=0 
            skip=1 
        } 
        !skip { print } 
        ' "$IN_PROGRESS_ORDERS" > temp.txt && mv temp.txt "$IN_PROGRESS_ORDERS"
    fi

    echo "Request $order_id has been $new_status."
    read -p "Press any key to return to the admin menu..." key
    admin_menu
}

# View completed requests
view_completed_requests() {
    clear
    echo "---------------------------------"
    echo "       Completed Requests"
    echo "---------------------------------"

    if [ -s "$HISTORY_FILE" ]; then
        cat "$HISTORY_FILE"
    else
        echo "No completed requests found."
    fi

    echo
    read -p "Press any key to return to the admin menu..." key
    admin_menu
}

approve_reject_prepaid() {
    clear
    echo "---------------------------------"
    echo "    Pending Prepaid Requests"
    echo "---------------------------------"

    # Display all pending prepaid requests nicely
    awk '
    /Username: / {username=$0}
    /Transaction ID: / {trans_id=$0}
    /Pages Requested: / {pages=$0}
    /Amount: / {amount=$0}
    /Status: / {status=$0}
    /^-----------------------------$/ {
        print username
        print trans_id
        print pages
        print amount
        print status
        print "-----------------------------"
    }
    ' "$PREPAID_REQUESTS"

    read -p "Enter Transaction ID to manage (or '0' to cancel): " trans_id
    if [ "$trans_id" == "0" ]; then
        admin_menu
        return
    fi

    # Validate Transaction ID exists
    if ! grep -q "^Transaction ID: $trans_id$" "$PREPAID_REQUESTS"; then
        echo "Invalid Transaction ID."
        read -p "Press any key to try again..." key
        approve_reject_prepaid
        return
    fi

    echo "1. Approve"
    echo "2. Reject"
    read -p "Choose action (1/2): " action

  case $action in
        1)
            # Extract the entire block including Username and other details
            block=$(awk -v id="$trans_id" '
                BEGIN { block=""; in_block=0 }
                /^-----------------------------$/ {
                    if (in_block) {
                        print block
                        exit
                    }
                    block=""
                    next
                }
                {
                    block = block $0 ORS
                    if ($0 ~ "Transaction ID: " id) {
                        in_block = 1
                    }
                }
            ' "$PREPAID_REQUESTS")


            # Append to prepaid.txt
            echo "$username:$trans_id:$pages" >> "$PREPAID_FILE"

          

            # Remove the request block from prepaid_requests.tx            # Remove the block from prepaid_requests.txt
awk -v id="$trans_id" '
    BEGIN { keep=1; block=""; found=0 }

    /^Username: / {
        block = $0 ORS
        keep = 1
        found = 0
        next
    }

    {
        block = block $0 ORS

        if ($0 == "Transaction ID: " id) {
            found = 1
        }

        if (/^-----------------------------$/) {
            if (!found) {
                printf "%s", block
            }
            block = ""
            found = 0
            next
        }
    }

    END {
        # Print remaining block if not terminated with dashed line
        if (!found && block != "") {
            printf "%s", block
        }
    }
' "$PREPAID_REQUESTS" > temp.txt && mv temp.txt "$PREPAID_REQUESTS"
;;

    2)
        # Just remove the block without adding to prepaid.txt
        awk -v trans_id="$trans_id" '
            BEGIN { in_block=0; print_block=1 }
            /^Username: / { buffer=""; in_block=0; print_block=1 }

            {
                buffer = buffer $0 ORS
                if ($0 == "Transaction ID: " trans_id) {
                    in_block = 1
                }
                if (in_block && /^-----------------------------$/) {
                    buffer = ""; print_block = 0; in_block = 0; next
                }
                if (!in_block && print_block) {
                    print buffer
                    buffer = ""
                }
            }
        ' "$PREPAID_REQUESTS" > temp.txt && mv temp.txt "$PREPAID_REQUESTS"

        

            echo "Prepaid package with Transaction ID $trans_id has been rejected."
        ;;
        *)
            echo "Invalid choice."
            read -p "Press any key to try again..." key
            approve_reject_prepaid
            return
        ;;
    esac

    read -p "Press any key to return to the admin menu..." key
    admin_menu
}


# User Registration
user_register() {
    clear
    echo "---------------------------------"
    echo "       User Registration "
    echo "---------------------------------"

    read -p "Enter your username: " username
    read -p "Enter your email: " email
    read -s -p "Enter your password: " password
    echo

    # Check if the user already exists
    if grep -q "$username" $USER_FILE; then
        echo "Username already exists! Please choose another username."
        read -p "Press any key to return to the welcome screen..." key
        welcome_screen
    else
        # Register the new user
        echo "$username:$email:$password" >> $USER_FILE
        echo "Registration successful! You can now log in."
        read -p "Press any key to return to the welcome screen..." key
        welcome_screen
    fi
}

see_purchased_packages() {
    clear
    echo "---------------------------------"
    echo "       Your Purchased Packages"
    echo "---------------------------------"

    # Fetch all packages for the current user
    user_packages=$(grep "^$username:" "$PREPAID_FILE")

    if [ -z "$user_packages" ]; then
        echo "You have no prepaid packages."
    else
        echo "Transaction ID          Pages Remaining"
        echo "---------------------------------------"
        echo "$user_packages" | awk -F: '{ printf "%-22s %s\n", $2, $3 }'

        # Calculate total pages remaining
        total_pages=$(echo "$user_packages" | awk -F: '{sum += $3} END {print sum}')
        echo "---------------------------------------"
        echo "Total pages remaining: $total_pages"
    fi

    echo
    read -p "Press any key to return to the user menu..." key
    user_menu
}

check_status() {
    clear
    echo "---------------------------------"
    echo "       Your Print Request Status"
    echo "---------------------------------"

    INPROGRESS_FILE="in_progress_orders.txt"  # set the correct file

    if grep -q "Username: $username" "$INPROGRESS_FILE"; then
        awk -v user="$username" '
        BEGIN { show=0; file=""; status="" }
        /Username: / { show = ($0 ~ user) }
        /File: / { if (show) file = $0 }
        /Status: / {
            if (show) {
                status = $0
                print file "\n" status "\n-----------------------------"
                file=""; status=""
            }
        }
        /^-----------------------------$/ { show=0 }
        ' "$INPROGRESS_FILE"
    else
        echo "No print requests found for user: $username"
    fi

    echo
    read -p "Press any key to return to the user menu..." key
    user_menu
}

user_menu() {
    clear
    echo "---------------------------------"
    echo "       User Dashboard"
    echo "---------------------------------"
    echo "1. Submit a Print Request"
    echo "2. Buy Prepaid Printing Package"
    echo "3. See History"
    echo "4. See Purchased Packages"
    echo "5. Check Print Status"
    echo "6. Logout"
    read -p "Choose an option: " user_option
    case $user_option in
        1) user_print_request ;;
        2) buy_prepaid_package ;;
        3) see_history ;;
        4) see_purchased_packages;;
        5) check_status;;
        6) welcome_screen;;
        *) echo "Invalid option." ; read -p "Press any key to return..." key ; user_menu ;;
    esac
}

# User Login
user_login() {
    clear
    echo "---------------------------------"
    echo "       User Login "
    echo "---------------------------------"

    read -p "Enter your username: " username
    read -s -p "Enter your password: " password
    echo

    login_successful=false

    while IFS=: read -r stored_user stored_email stored_pass; do
        if [[ "$username" == "$stored_user" && "$password" == "$stored_pass" ]]; then
            login_successful=true
            break
        fi
    done < "$USER_FILE"

    if [ "$login_successful" = true ]; then
        echo "Login successful!"
        user_menu
    else
        echo "Invalid username or password."
        read -p "Press any key to return to the welcome screen..." key
        welcome_screen
    fi
}

# Buy Prepaid Printing Package
buy_prepaid_package() {
    clear
    echo "---------------------------------"
    echo "       Buy Prepaid Package"
    echo "---------------------------------"

    echo "Choose a package:"
    echo "1. 50 pages - 100 BDT"
    echo "2. 100 pages - 180 BDT"
    echo "3. 200 pages - 350 BDT"
    read -p "Enter your choice (1/2/3): " package_choice

    case $package_choice in
        1) pages=50 ; amount=100 ;;
        2) pages=100 ; amount=180 ;;
        3) pages=200 ; amount=350 ;;
        *) echo "Invalid choice!" ; read -p "Press any key to return..." key ; user_menu ; return ;;
    esac

    read -p "Enter your bKash Transaction ID: " bkash_id
echo "DEBUG: username='$username', bkash_id='$bkash_id', pages='$pages', amount='$amount'"

   cat <<EOF >> "$PREPAID_REQUESTS"
Username: $username
Transaction ID: $bkash_id
Pages Requested: $pages
Amount: ${amount} BDT
Status: Pending
-----------------------------
EOF

    echo "Your prepaid package request has been submitted for admin approval."
    echo "You'll be able to use the pages once approved."
    read -p "Press any key to return to the user menu..." key
    user_menu
}

# Print Request Submission
user_print_request() {
    clear
    echo "---------------------------------"
    echo "       Print Request Submission "
    echo "---------------------------------"

    # Collect print job details from the user
    read -p "Enter the file name to print (PDF): " file_name
    read -p "Enter the number of copies: " num_copies
    read -p "Enter the number of pages in the document: " num_pages
    read -p "Choose print color (1 for Black & White, 2 for Color): " color_choice
    if [ "$color_choice" -eq 1 ]; then
        color="Black & White"
    else
        color="Color"
    fi
    read -p "Choose print type (1 for One-Sided, 2 for Double-Sided): " print_type
    if [ "$print_type" -eq 1 ]; then
        print_type="One-Sided"
    else
        print_type="Double-Sided"
    fi

    # Check payment method (Transaction ID or Prepaid)
    echo "Enter bKash Transaction ID (or type 'prepaid' for prepaid users):"
    read payment_method

    # Total pages requested
    total_pages=$((num_pages * num_copies))

    if [ "$payment_method" == "prepaid" ]; then
        prepaid_entry=$(grep "^$username:" "$PREPAID_FILE")
        if [ -z "$prepaid_entry" ]; then
            echo "You don't have a prepaid package. Please enter a valid transaction ID."
            read -p "Enter bKash Transaction ID: " payment_method
        else
            balance=$(echo "$prepaid_entry" | cut -d':' -f3)
            if [ "$balance" -lt "$total_pages" ]; then
                echo "Not enough prepaid balance. You have $balance pages, but need $total_pages."
                read -p "Enter bKash Transaction ID instead: " payment_method
            else
                echo "Prepaid balance OK. Your request will be processed after admin approval."
            fi
        fi
    fi

    # Generate a unique order ID (using timestamp)
    order_id=$(date +%s)

    # Save the order in in_progress_orders.txt
    echo "OrderID: $order_id" >> "$IN_PROGRESS_ORDERS"
    echo "Username: $username" >> "$IN_PROGRESS_ORDERS"
    echo "File: $file_name" >> "$IN_PROGRESS_ORDERS"
    echo "Copies: $num_copies" >> "$IN_PROGRESS_ORDERS"
    echo "Pages per Copy: $num_pages" >> "$IN_PROGRESS_ORDERS"
    echo "Color: $color" >> "$IN_PROGRESS_ORDERS"
    echo "Print Type: $print_type" >> "$IN_PROGRESS_ORDERS"
    echo "Payment Method: $payment_method" >> "$IN_PROGRESS_ORDERS"
    echo "Status: Pending" >> "$IN_PROGRESS_ORDERS"
    echo "-----------------------------" >> "$IN_PROGRESS_ORDERS"

    echo "Your print request has been submitted. It is currently pending."
    read -p "Press any key to return to the user dashboard..." key
    user_menu
}

see_history() {
    clear
    echo "---------------------------------"
    echo "       Your Print History"
    echo "---------------------------------"

    if grep -q "Username: $username" "$HISTORY_FILE"; then
        # Show only this user's history block by block
        awk -v user="$username" '
        BEGIN { show=0 }
        /Username: / { show = ($0 ~ user) }
        /^-----------------------------$/ { if (show) print ""; show=0 }
        { if (show) print }
        ' "$HISTORY_FILE"
    else
        echo "No history found for user: $username"
    fi

    echo
    read -p "Press any key to return to the dashboard..." key
    user_menu
}

# Exit the program
exit_screen() {
    clear
    echo "---------------------------------"
    echo " Thank you for using Printing Management System "
    echo "---------------------------------"
    exit 0
}

# Welcome Screen Function
welcome_screen() {
    clear
    echo "---------------------------------"
    echo " Welcome to Printing Management System "
    echo "---------------------------------"
    echo
    echo "1. Register as User"
    echo "2. User Login"
    echo "3. Register as Admin"
    echo "4. Admin Login"
    echo "5. Exit"
    echo
    read -p "Please choose an option: " option
    case $option in
        1) user_register ;;
        2) user_login ;;
        3) admin_register ;;
        4) admin_login ;;
        5) exit_screen ;;
        *) echo "Invalid option!" ; welcome_screen ;;
    esac
}

welcome_screen
