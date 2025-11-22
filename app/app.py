# Main application file contains Welcome Screen and All Available Features
# Importing necessary modules for the website
from flask import Flask, render_template, request, redirect, url_for, flash
import storage

# Load data from persistent storage
items_db = storage.load_items()   # Load items database data from disk
users_db = storage.load_users()   # Load users database data from disk


def _initial_counter(db):   # Calculate initial counter from existing data
    if not db:
        return 1
    return max(int(key) for key in db.keys()) + 1


item_id_counter = _initial_counter(items_db)   # Creation of Item ID Counter value
user_id_counter = _initial_counter(users_db)   # Creation of User ID Counter value

app = Flask(__name__, template_folder="website")
app.secret_key = "supersecretkey"  # Needed for flashing messages

# Helper function for menu links
def get_menu_links(): # Return list of menu links
    return [
        ("", "Add New Item", "add_item"),
        ("", "Delete Item", "delete_item"),
        ("", "Modify Item", "modify_item_select"),
        ("", "Assign Item", "assign_item"),
        ("", "Add New User", "add_user"),
        ("", "Show All Users", "show_users"),
        ("", "Show Items by User", "show_user_items_select"),
        ("", "Show All Items", "show_stock_items"),
        ("", "Calculate Stock", "stock_by_categories"),
    ]

# Website App Routes
@app.route("/") # Welcome Screen Route
def index(): # Render Welcome Screen
    # Calculate totals for welcome screen
    total_users = len(users_db)
    total_items = len(items_db)
    items_in_stock = sum(1 for item in items_db.values() if item["status"] == "In Stock")
    items_assigned = sum(1 for item in items_db.values() if item["status"] == "Assigned")
    items_by_category = {"Assets": 0, "Accessories": 0, "Licenses": 0}
    for item in items_db.values():
        cat = item.get("main_category", "")
        if cat in items_by_category:
            items_by_category[cat] += 1
    return render_template(
        "index.html",
        total_users=total_users,
        total_items=total_items,
        items_in_stock=items_in_stock,
        items_assigned=items_assigned,
        items_by_category=items_by_category,
        menu_links=get_menu_links(),
    )

@app.route("/add_item", methods=["GET", "POST"]) # Add New Item Route
def add_item():
    global item_id_counter
    if request.method == "POST":
        main_category = request.form.get("main_category")
        sub_category = request.form.get("sub_category")
        manufacturer = request.form.get("manufacturer")
        model = request.form.get("model")
        price = request.form.get("price")

        # Basic validation
        if main_category not in ["Assets", "Accessories", "Licenses"]:
            flash("Invalid main category.", "danger")
            return redirect(url_for("add_item"))
        if not price or not price.replace('.', '', 1).isdigit():
            flash("Price must be a valid number.", "danger")
            return redirect(url_for("add_item"))

        item_id = str(item_id_counter)
        item_id_counter += 1

        items_db[item_id] = {
            "id": item_id,
            "main_category": main_category,
            "sub_category": sub_category,
            "manufacturer": manufacturer,
            "model": model,
            "price": float(price),
            "quantity": 1,
            "status": "In Stock",
            "assigned_to": None,
        }
        storage.save_items(items_db)   # Save items database to disk
        flash(f"Item '{sub_category} {manufacturer} {model}' added with ID {item_id}.", "success")
        return redirect(url_for("add_item"))

    return render_template("add_item.html", menu_links=get_menu_links())

@app.route("/delete_item", methods=["GET", "POST"]) # Delete Item Route
def delete_item():
    if request.method == "POST":
        item_id = request.form.get("item_id")
        if not item_id or item_id not in items_db:
            flash(f"No item found with ID {item_id}.", "danger")
            return redirect(url_for("delete_item"))
        # Remove from assigned user's item list if assigned
        assigned_to = items_db[item_id]["assigned_to"]
        if assigned_to and assigned_to in users_db:
            if item_id in users_db[assigned_to]["items"]:
                users_db[assigned_to]["items"].remove(item_id)
                storage.save_users(users_db)   # Save users database to disk
        del items_db[item_id]
        storage.save_items(items_db)   # Save items database to disk
        flash(f"Item with ID {item_id} deleted.", "success")
        return redirect(url_for("delete_item"))
    return render_template("delete_item.html", menu_links=get_menu_links())

@app.route("/modify_item", methods=["GET"]) # Modify Item Route
def modify_item_select():
    return render_template("modify_item_select.html", menu_links=get_menu_links())

@app.route("/modify_item_form", methods=["GET", "POST"]) # Modify Item Form Route
def modify_item_form():
    item_id = request.args.get("item_id") or request.form.get("item_id")
    if not item_id or item_id not in items_db:
        flash("Item ID not found.", "danger")
        return redirect(url_for("modify_item_select"))

    item = items_db[item_id]
    if request.method == "POST":
        sub_category = request.form.get("sub_category")
        manufacturer = request.form.get("manufacturer")
        model = request.form.get("model")
        price = request.form.get("price")
        if not price or not price.replace('.', '', 1).isdigit():
            flash("Price must be a valid number.", "danger")
            return redirect(url_for("modify_item_form", item_id=item_id))
        item["sub_category"] = sub_category
        item["manufacturer"] = manufacturer
        item["model"] = model
        item["price"] = float(price)
        storage.save_items(items_db)   # Save items database to disk
        flash(f"Item ID {item_id} updated successfully.", "success")
        return redirect(url_for("modify_item_select"))

    return render_template("modify_item_form.html", item=item, menu_links=get_menu_links())

@app.route("/assign_item", methods=["GET", "POST"]) # Assign Item Route
def assign_item():
    if request.method == "POST":
        item_id = request.form.get("item_id")
        user_id = request.form.get("user_id")
        if not item_id or item_id not in items_db:
            flash(f"Item ID {item_id} does not exist.", "danger")
            return redirect(url_for("assign_item"))
        if not user_id or user_id not in users_db:
            flash(f"User ID {user_id} does not exist.", "danger")
            return redirect(url_for("assign_item"))
        item = items_db[item_id]
        if item["status"] == "Assigned":
            flash("Item is already assigned.", "danger")
            return redirect(url_for("assign_item"))
        # Assign item
        item["status"] = "Assigned"
        item["assigned_to"] = user_id
        users_db[user_id]["items"].append(item_id)
        storage.save_items(items_db)   # Save items database to disk
        storage.save_users(users_db)   # Save users database to disk
        flash(f"Item ID {item_id} assigned to user {users_db[user_id]['name']}.", "success")
        return redirect(url_for("assign_item"))
    return render_template("assign_item.html", menu_links=get_menu_links())

@app.route("/add_user", methods=["GET", "POST"]) # Add New User Route
def add_user():
    global user_id_counter
    if request.method == "POST":
        full_name = request.form.get("full_name")
        if not full_name or not full_name.replace(" ", "").isalpha():
            flash("Full name must only contain letters and spaces.", "danger")
            return redirect(url_for("add_user"))
        user_id = str(user_id_counter)
        user_id_counter += 1
        users_db[user_id] = {"name": full_name, "items": []}
        storage.save_users(users_db)   # Save users database to disk
        flash(f"User '{full_name}' added with ID {user_id}.", "success")
        return redirect(url_for("add_user"))
    return render_template("add_user.html", menu_links=get_menu_links())

@app.route("/show_users") # Show All Users Route
def show_users():
    return render_template("show_users.html", users=users_db, menu_links=get_menu_links())

@app.route("/show_user_items", methods=["GET", "POST"]) # Show Items by User Route
def show_user_items_select():
    if request.method == "POST":
        user_id = request.form.get("user_id")
        if not user_id or user_id not in users_db:
            flash("User ID not found.", "danger")
            return redirect(url_for("show_user_items_select"))
        return redirect(url_for("show_user_items", user_id=user_id))
    
    # GET method: render user selection form
    return render_template("show_user_items_select.html", users=users_db, menu_links=get_menu_links())


@app.route("/show_user_items/<user_id>") # Show Items by User ID Route
def show_user_items(user_id):
    if user_id not in users_db:
        flash("User ID not found.", "danger")
        return redirect(url_for("show_user_items_select"))
    user = users_db[user_id]
    items = [items_db[item_id] for item_id in user["items"] if item_id in items_db]
    return render_template("show_user_items.html", user=user, user_id=user_id, items=items, menu_links=get_menu_links())

@app.route("/show_stock_items") # Show All Items Route
def show_stock_items():
    return render_template("show_stock_items.html", items=items_db.values(), menu_links=get_menu_links())

@app.route("/stock_by_categories") # Calculate Stock by Categories Route
def stock_by_categories():
    stock = {"Assets": 0, "Accessories": 0, "Licenses": 0}
    for item in items_db.values():
        cat = item.get("main_category")
        if cat in stock:
            stock[cat] += item["price"] * item["quantity"]
    return render_template("stock_by_categories.html", stock=stock, menu_links=get_menu_links())

if __name__ == "__main__": # Run the application on port 31415
    app.run(host="0.0.0.0", port=31415, debug=True)