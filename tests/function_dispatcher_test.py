

# STATE: WAIT_FOR_INPUT

    # → CLASSIFY_INTENT (NLP)
        # Train a classifier:
            # Input: user text
            # Output: function name

        # Use spaCy NLTK scikit-learn 
        # Figure out how to handle argument extaction + parameters
    # → CALL_FUNCTION 
        # With extracted parameters

    # → HANDLE_RESPONSE
        # Give feedback
 
    # → ASK_FOLLOWUP (optional)f