

# **Project Documentation: EuroLex Processing Tool**

## **Overview**
The EuroLex Processing Tool is a Flutter-based application designed to process, analyze, and upload legal documents (Celex numbers) to an OpenSearch server. It provides functionality for:
- Parsing and processing multilingual HTML and RDF metadata.
- Extracting and validating paragraphs.
- Uploading structured data to OpenSearch.
- Logging and debugging operations.
- Searching and displaying indexed data.

---

## **File Structure**
The lib folder contains the core files of the project. Below is a detailed breakdown of each file, its purpose, and its components.

---

## **1. `main.dart`**
### **Purpose**
The entry point of the Flutter application. It initializes the app and sets up the tabbed navigation structure.

### **Classes**
#### **`MainTabbedApp`**
- **Type:** `StatefulWidget`
- **Purpose:** Manages the tabbed navigation for the app.
- **Tabs:**
  - **Search:** For querying indexed data.
  - **Auto Analyser:** For analyzing and processing data automatically.
  - **Setup:** For configuring the application.
  - **Data Processing:** For processing and uploading data.

#### **Methods**
- **`build(BuildContext context)`**
  - **Description:** Builds the UI for the app, including the `TabBar` and `TabBarView`.
  - **Returns:** A `Widget` containing the tabbed interface.

### **How It Works**
- The `MainTabbedApp` widget initializes the app and provides a `DefaultTabController` for managing navigation between tabs.
- Each tab corresponds to a specific functionality, such as searching, analyzing, or processing data.

---

## **2. `preparehtml.dart`**
### **Purpose**
Handles HTML parsing, Celex number processing, and server communication for fetching indices.

### **Functions**
#### **`getListIndices(server)`**
- **Description:** Fetches a list of indices from the OpenSearch server.
- **Parameters:**
  - `server`: The OpenSearch server URL.
- **Returns:** A `Future` that resolves to a list of indices.
- **Usage:** Called from dropdowns or other UI components to populate index options.

#### **`manualCelexListUpload(manualCelexListEntry, newIndexName)`**
- **Description:** Processes a list of manually entered Celex numbers.
- **Parameters:**
  - `manualCelexListEntry`: A list of Celex numbers entered by the user.
  - `newIndexName`: The OpenSearch index name.
- **Returns:** A `Future` that resolves when the upload is complete.
- **Usage:** Called from the manual Celex upload UI.

### **Widgets**
#### **Manual Celex List**
- **Description:** A widget for manually entering Celex numbers.
- **Components:**
  - A `TextField` for input.
  - A button to process the entered numbers.

---

## **3. `search.dart`**
### **Purpose**
Manages the search functionality, including dropdowns and search input.

### **Classes**
#### **`SearchTabWidget`**
- **Type:** `StatefulWidget`
- **Purpose:** Provides the UI for the search tab.

#### **Methods**
- **`build(BuildContext context)`**
  - **Description:** Builds the search tab UI, including the search bar and dropdowns.
  - **Returns:** A `Widget` containing the search interface.

### **Functions**
#### **`startSearch(query, index)`**
- **Description:** Executes a search query on the selected index.
- **Parameters:**
  - `query`: The search query string.
  - `index`: The selected OpenSearch index.
- **Returns:** A `Future` that resolves with the search results.
- **Usage:** Called when the user submits a search query.

#### **`populateDropdown()`**
- **Description:** Dynamically populates the dropdown with indices fetched from the server.
- **Returns:** A `Future` that resolves when the dropdown is populated.
- **Usage:** Called during the initialization of the search tab.

---

## **4. processDOM.dart**
### **Purpose**
Processes HTML DOM elements and extracts specific data.

### **Classes**
#### **`DomProcessor`**
- **Type:** Utility Class
- **Purpose:** Provides static methods for processing HTML content.

#### **Methods**
- **`parseHtmlString(String htmlString)`**
  - **Description:** Parses an HTML string and extracts the plain text content.
  - **Parameters:**
    - `htmlString`: The HTML content as a string.
  - **Returns:** A `String` containing the text content of the HTML.

### **Functions**
#### **`extractParagraphs`**
- **Description:** Processes multilingual HTML content, extracts paragraphs, validates file names, and uploads structured data to OpenSearch.
- **Parameters:**
  - `htmlEN`, `htmlSK`, `htmlCZ`: HTML content in English, Slovak, and Czech.
  - `metadata`: RDF metadata associated with the files.
  - `dirID`: Directory ID for logging purposes.
  - `indexName`: OpenSearch index name.
- **Returns:** A `List<Map<String, dynamic>>` containing structured data for each paragraph.
- **Usage:** Called from other parts of the app to process multilingual files.

#### **`openSearchUpload`**
- **Description:** Uploads structured data to OpenSearch in bulk using the `_bulk` API.
- **Parameters:**
  - `json`: The structured data to upload.
  - `indexName`: The OpenSearch index name.
- **Usage:** Called from `extractParagraphs` to upload processed data.

#### **`sendToOpenSearch`**
- **Description:** Sends NDJSON data to the OpenSearch `_bulk` API.
- **Parameters:**
  - `url`: The OpenSearch endpoint URL.
  - `bulkData`: The NDJSON data to upload.
- **Returns:** A `Future<String>` containing the response from OpenSearch.
- **Usage:** Called from `openSearchUpload` to send data to OpenSearch.

#### **`getmetadata`**
- **Description:** Extracts the Celex number from RDF metadata.
- **Parameters:**
  - `metadataRDF`: The RDF metadata as a string.
- **Returns:** A `String` containing the Celex number or `'not found'` if no Celex number is present.
- **Usage:** Called from `extractParagraphs` to extract the Celex number.

---

## **5. `logger.dart`**
### **Purpose**
Provides logging functionality for debugging and traceability.

### **Classes**
#### **`LogManager`**
- **Purpose:** Manages log files and writes log entries.

#### **Methods**
- **`log(String message)`**
  - **Description:** Writes a log entry to the log file.
  - **Parameters:**
    - `message`: The log message.
  - **Usage:** Called throughout the app to log operations.

- **`readLogs()`**
  - **Description:** Reads the log file and returns its content.
  - **Returns:** A `Future<String>` containing the log content.

---

## **6. `display.dart`**
### **Purpose**
Handles text highlighting and fetching context from OpenSearch.

### **Functions**
#### **`highlightFoundWords(returnedResult, foundWords)`**
- **Description:** Highlights specific words in a given text.
- **Parameters:**
  - `returnedResult`: The text to highlight.
  - `foundWords`: The words to highlight.
- **Returns:** A `TextSpan` with highlighted words.

#### **`getContext(celex, pointer)`**
- **Description:** Fetches context for a given Celex number and pointer.
- **Parameters:**
  - `celex`: The Celex number.
  - `pointer`: The pointer for context retrieval.
- **Returns:** A `Future<List>` containing the context data.

---

## **7. `analyser.dart`**
### **Purpose**
Provides functionality for analyzing data and performing search queries.

### **Functions**
#### **`searchQuery(query, queryString)`**
- **Description:** Executes a search query and returns the results.
- **Parameters:**
  - `query`: The search query.
  - `queryString`: The query string.
- **Returns:** A `Future<List>` containing the search results.

---

## **8. `browseFiles.dart`**
### **Purpose**
Manages file browsing functionality, allowing users to navigate directories and select files.

### **Functions**
#### **`listFilesInDirEN()`**
- **Description:** Lists files in the English directory.
- **Returns:** A `List<String>` containing the file names.

#### **`pickAndLoadFile()`**
- **Description:** Opens a file picker dialog and loads the selected file's content.
- **Returns:** A `Future<String>` containing the file content.

---

## **How Components Interact**
1. **User Interaction:**
   - The user interacts with the app via the tabbed interface.
   - Tabs include options for searching, uploading, and processing data.

2. **Data Processing:**
   - HTML and RDF files are parsed and validated.
   - Extracted data is structured and uploaded to OpenSearch.

3. **Search and Display:**
   - The user can search indexed data using the search tab.
   - Results are displayed with highlighted keywords.

4. **Logging:**
   - All operations are logged for debugging and traceability.




